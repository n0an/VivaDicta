// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AuthenticationServices
import Network
import os

/// Manages OAuth authentication flows — sign-in, token refresh, and credential storage.
/// MainActor-isolated for safe interaction with UI and Keychain in Swift 6.
@MainActor
final class OAuthManager: Sendable {
    static let shared = OAuthManager()

    private let logger = Logger(category: .oauthManager)

    /// In-memory cache of credentials.
    private var credentials: [String: OAuthCredential] = [:]

    private init() {}

    // MARK: - Public API

    /// Whether the user is signed in for a given provider.
    func isSignedIn(provider: some OAuthProvider) -> Bool {
        loadCredential(for: provider) != nil
    }

    /// Returns the account email for a given provider, if signed in.
    func accountEmail(for provider: some OAuthProvider) -> String? {
        loadCredential(for: provider)?.accountEmail
    }

    /// iOS sign-in using ASWebAuthenticationSession.
    func signIn(provider: some OAuthProvider) async throws -> OAuthCredential {
        let pkce = PKCEGenerator.generate()
        let state = PKCEGenerator.generateState()

        // Build authorization URL
        var components = URLComponents(string: provider.authorizeURL)!
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: provider.clientId),
            URLQueryItem(name: "redirect_uri", value: provider.redirectURI),
            URLQueryItem(name: "scope", value: provider.scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        for (key, value) in provider.extraAuthParams {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems

        guard let authURL = components.url else {
            throw OAuthError.tokenExchangeFailed("Invalid authorization URL")
        }

        // Start local callback server that bridges localhost redirect → custom scheme
        let callbackServer = OAuthCallbackServer(port: 1455, customSchemeRedirectBase: "vivadicta://auth/callback")
        let listener = try await callbackServer.start()
        defer { listener.cancel() }

        logger.logInfo("OAuth callback server started on port \(callbackServer.port)")

        // Use ASWebAuthenticationSession with custom scheme interception
        // The flow: browser → OpenAI → redirect to localhost → local server → 302 to vivadicta:// → session intercepts
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "vivadicta"
            ) { url, error in
                if let error {
                    continuation.resume(throwing: OAuthError.authorizationDenied(error.localizedDescription))
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: OAuthError.timeout)
                }
            }
            session.presentationContextProvider = ASWebAuthSessionContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        // Parse callback URL for code + state
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw OAuthError.invalidResponse
        }
        let params = Dictionary(uniqueKeysWithValues: (callbackComponents.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        guard let returnedState = params["state"], returnedState == state else {
            throw OAuthError.stateMismatch
        }
        guard let code = params["code"] else {
            throw OAuthError.authorizationDenied(params["error_description"] ?? params["error"] ?? "Unknown error")
        }

        // Exchange code for tokens
        let credential = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: pkce.verifier,
            state: state,
            provider: provider
        )

        // Store credential
        saveCredential(credential, for: provider)
        logger.logInfo("OAuth sign-in complete for \(provider.providerName)")

        return credential
    }

    /// Signs out by removing the stored credential.
    func signOut(provider: some OAuthProvider) {
        credentials.removeValue(forKey: provider.keychainKey)
        KeychainService.shared.delete(forKey: provider.keychainKey, syncable: false)
        logger.logInfo("Signed out from \(provider.providerName)")
    }

    /// Returns a valid access token, refreshing if needed.
    func validAccessToken(for provider: some OAuthProvider) async throws -> (token: String, accountId: String?, projectId: String?) {
        guard var credential = loadCredential(for: provider) else {
            throw OAuthError.noCredential
        }

        if credential.isExpiringSoon {
            logger.logInfo("Token expiring soon, refreshing for \(provider.providerName)")
            credential = try await refreshToken(credential: credential, provider: provider)
            saveCredential(credential, for: provider)
        }

        return (credential.accessToken, credential.accountId, credential.projectId)
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, codeVerifier: String, state: String, provider: some OAuthProvider) async throws -> OAuthCredential {
        var body = [
            "grant_type": "authorization_code",
            "client_id": provider.clientId,
            "redirect_uri": provider.redirectURI,
            "code": code,
            "code_verifier": codeVerifier,
            "state": state
        ]

        // Include client_secret when the provider requires it (e.g. Google)
        if let secret = provider.clientSecret {
            body["client_secret"] = secret
        }

        // OpenAI doesn't use state in token exchange
        if !provider.tokenRequestUsesJSON {
            body.removeValue(forKey: "state")
        }

        return try await tokenRequest(body: body, provider: provider)
    }

    // MARK: - Token Refresh

    private func refreshToken(credential: OAuthCredential, provider: some OAuthProvider) async throws -> OAuthCredential {
        var body = [
            "grant_type": "refresh_token",
            "client_id": provider.clientId,
            "refresh_token": credential.refreshToken
        ]

        // Include client_secret when the provider requires it (e.g. Google)
        if let secret = provider.clientSecret {
            body["client_secret"] = secret
        }

        // Retry up to 3 times with exponential backoff
        var lastError: Error?
        let delays: [TimeInterval] = [0.25, 0.5, 1.0]

        for (attempt, delay) in delays.enumerated() {
            do {
                var refreshed = try await tokenRequest(body: body, provider: provider)
                // Preserve projectId from the original credential (project doesn't change on refresh)
                if refreshed.projectId == nil, let existingProjectId = credential.projectId {
                    refreshed = OAuthCredential(
                        accessToken: refreshed.accessToken,
                        refreshToken: refreshed.refreshToken,
                        expiresAt: refreshed.expiresAt,
                        accountId: refreshed.accountId ?? credential.accountId,
                        accountEmail: refreshed.accountEmail ?? credential.accountEmail,
                        projectId: existingProjectId
                    )
                }
                return refreshed
            } catch {
                lastError = error
                logger.logWarning("Token refresh attempt \(attempt + 1) failed: \(error.localizedDescription)")
                if attempt < delays.count - 1 {
                    try await Task.sleep(for: .seconds(delay))
                }
            }
        }

        throw OAuthError.tokenRefreshFailed(lastError?.localizedDescription ?? "Unknown error")
    }

    // MARK: - Shared Token Request

    private func tokenRequest(body: [String: String], provider: some OAuthProvider) async throws -> OAuthCredential {
        guard let url = URL(string: provider.tokenURL) else {
            throw OAuthError.tokenExchangeFailed("Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if provider.tokenRequestUsesJSON {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        } else {
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            let formBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            request.httpBody = formBody.data(using: .utf8)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.tokenExchangeFailed("Invalid JSON response")
        }

        guard let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("Missing tokens in response")
        }

        let expiresIn = json["expires_in"] as? TimeInterval ?? 3600
        let expiresAt = Date().addingTimeInterval(expiresIn)

        // Extract account info
        var accountId: String?
        var email: String?

        if let userinfoURL = provider.userinfoURL {
            // Fetch account info from userinfo endpoint (e.g. Google)
            let info = await fetchUserInfo(url: userinfoURL, accessToken: accessToken, provider: provider)
            accountId = info.id
            email = info.email
        } else if let claims = OpenAIChatGPTOAuthProvider.decodeJWTPayload(accessToken) {
            // Extract from JWT claims (OpenAI)
            let info = provider.extractAccountInfo(from: claims)
            accountId = info.id
            email = info.email
        }

        // Run post-auth setup (e.g. Google Cloud project discovery)
        let projectId = try? await provider.postAuthSetup(accessToken: accessToken)

        return OAuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            accountId: accountId,
            accountEmail: email,
            projectId: projectId
        )
    }

    // MARK: - User Info

    private func fetchUserInfo(url: String, accessToken: String, provider: some OAuthProvider) async -> (id: String?, email: String?) {
        guard let userinfoURL = URL(string: url) else { return (nil, nil) }

        var request = URLRequest(url: userinfoURL)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }

        return provider.extractAccountInfo(from: json)
    }

    // MARK: - Credential Storage

    private func saveCredential(_ credential: OAuthCredential, for provider: some OAuthProvider) {
        credentials[provider.keychainKey] = credential
        if let data = try? JSONEncoder().encode(credential) {
            KeychainService.shared.save(data: data, forKey: provider.keychainKey, syncable: false)
        }
    }

    private func loadCredential(for provider: some OAuthProvider) -> OAuthCredential? {
        // Check in-memory cache first
        if let cached = credentials[provider.keychainKey] {
            return cached
        }

        // Load from Keychain
        guard let data = KeychainService.shared.getData(forKey: provider.keychainKey, syncable: false),
              let credential = try? JSONDecoder().decode(OAuthCredential.self, from: data) else {
            return nil
        }

        // Don't return expired credentials with no way to refresh
        if credential.isExpired && credential.refreshToken.isEmpty {
            KeychainService.shared.delete(forKey: provider.keychainKey, syncable: false)
            return nil
        }

        credentials[provider.keychainKey] = credential
        return credential
    }
}
