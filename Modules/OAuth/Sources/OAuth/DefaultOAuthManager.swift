// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AuthenticationServices
import Keychain
import Network
import Networking
import os

/// Manages OAuth authentication flows - sign-in, token refresh, and credential storage.
/// MainActor-isolated for safe interaction with UI and Keychain in Swift 6.
@MainActor
public final class DefaultOAuthManager: OAuthManager {
    private let logger = Logger(oauthCategory: "OAuthManager")
    private let keychain: any KeychainService
    private let networkService: any NetworkService
    private let backgroundTaskService: (any BackgroundTaskService)?

    /// In-memory cache of credentials.
    private var credentials: [String: OAuthCredential] = [:]

    public init(
        keychain: any KeychainService,
        networkService: any NetworkService = DefaultNetworkService(category: "OAuthManager"),
        backgroundTaskService: (any BackgroundTaskService)? = nil
    ) {
        self.keychain = keychain
        self.networkService = networkService
        self.backgroundTaskService = backgroundTaskService
    }

    // MARK: - Public API

    /// Whether the user is signed in for a given provider.
    public func isSignedIn(provider: some OAuthProvider) -> Bool {
        loadCredential(for: provider) != nil
    }

    /// Returns the account email for a given provider, if signed in.
    public func accountEmail(for provider: some OAuthProvider) -> String? {
        loadCredential(for: provider)?.accountEmail
    }

    /// iOS sign-in using ASWebAuthenticationSession.
    public func signIn(provider: some OAuthProvider) async throws -> OAuthCredential {
        let pkce = PKCEGenerator.generate()
        let state = PKCEGenerator.generateState()

        // Build authorization URL
        guard var components = URLComponents(string: provider.authorizeURL) else {
            throw OAuthError.tokenExchangeFailed("Invalid authorization URL")
        }
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

        // Start local callback server that bridges localhost redirect -> custom scheme
        let callbackPort: UInt16 = {
            if let urlComponents = URLComponents(string: provider.redirectURI),
               let port = urlComponents.port {
                return UInt16(port)
            }
            return 1455
        }()
        let callbackServer = OAuthCallbackServer(port: callbackPort, customSchemeRedirectBase: "vivadicta://auth/callback")
        let listener = try await callbackServer.start()
        defer { listener.cancel() }

        logger.logInfo("OAuth callback server started on port \(callbackServer.port)")

        // Use ASWebAuthenticationSession with custom scheme interception
        // The flow: browser -> OpenAI -> redirect to localhost -> local server -> 302 to vivadicta:// -> session intercepts
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
            #if os(iOS)
            session.presentationContextProvider = ASWebAuthSessionContextProvider.shared
            #endif
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
    public func signOut(provider: some OAuthProvider) {
        credentials.removeValue(forKey: provider.keychainKey)
        keychain.delete(forKey: provider.keychainKey, syncable: false)
        logger.logInfo("Signed out from \(provider.providerName)")
    }

    /// Returns a valid access token, refreshing if needed.
    public func validAccessToken(for provider: some OAuthProvider) async throws -> (token: String, accountId: String?, projectId: String?) {
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

    // MARK: - Device Code Flow (RFC 8628)

    /// Requests a device code. Every field is validated before use: a malformed
    /// or hostile payload must not reach the UI, and the verification URI is
    /// opened in a browser so it is constrained to `https`.
    public func startDeviceCodeFlow(provider: some OAuthProvider) async throws -> DeviceCodeResponse {
        guard let endpoint = provider.deviceCodeURL, let url = URL(string: endpoint) else {
            throw OAuthError.deviceCodeUnsupported(provider.providerName)
        }

        var fields = [
            "client_id": provider.clientId,
            "scope": provider.scopes
        ]
        for (key, value) in provider.deviceAuthExtraParams {
            fields[key] = value
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded(fields).data(using: .utf8)

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.deviceCodeFailed("HTTP \(httpResponse.statusCode): invalid response")
        }
        guard httpResponse.statusCode == 200 else {
            throw OAuthError.deviceCodeFailed(Self.errorDetail(json) ?? "HTTP \(httpResponse.statusCode)")
        }

        guard let deviceCode = Self.nonEmptyString(json["device_code"]),
              let userCode = Self.nonEmptyString(json["user_code"]),
              let rawVerificationURI = Self.nonEmptyString(json["verification_uri"]),
              let verificationURI = Self.validatedHTTPSURI(rawVerificationURI) else {
            throw OAuthError.deviceCodeFailed("Incomplete device authorization response")
        }

        // RFC 8628 makes `interval` optional and permits 0; fall back to the
        // conventional 5s rather than hammering the endpoint.
        let interval: Int = {
            guard let raw = json["interval"] as? Int, raw > 0 else { return 5 }
            return raw
        }()

        let expiresIn: Int = {
            guard let raw = json["expires_in"] as? Int, raw > 0 else { return 900 }
            return raw
        }()

        logger.logInfo("Device code issued for \(provider.providerName), expires in \(expiresIn)s")

        return DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationUri: verificationURI,
            verificationUriComplete: Self.nonEmptyString(json["verification_uri_complete"]).flatMap(Self.validatedHTTPSURI),
            interval: interval,
            expiresIn: expiresIn
        )
    }

    public func pollForDeviceCodeToken(
        provider: some OAuthProvider,
        deviceCode: DeviceCodeResponse
    ) async throws -> OAuthCredential {
        var interval = max(deviceCode.interval, 1)
        let deadline = Date().addingTimeInterval(TimeInterval(deviceCode.expiresIn))

        // The user leaves for Safari to authorize, so the app backgrounds while
        // we poll. Hold a background assertion the way the Copilot flow does.
        let backgroundTaskId = backgroundTaskService?.beginBackgroundTask(name: "OAuthDeviceCodePoll", onExpiration: {})
        defer {
            if let backgroundTaskId {
                backgroundTaskService?.endBackgroundTask(backgroundTaskId)
            }
        }

        while Date() < deadline {
            try await Task.sleep(for: .seconds(interval))

            switch try await pollDeviceCodeOnce(provider: provider, deviceCode: deviceCode.deviceCode) {
            case .authorized(let credential):
                saveCredential(credential, for: provider)
                logger.logInfo("Device-code sign-in complete for \(provider.providerName)")
                return credential
            case .pending:
                continue
            case .slowDown(let serverInterval):
                interval = max(serverInterval ?? interval + 5, interval + 1)
                logger.logInfo("Device-code poll throttled, backing off to \(interval)s")
            case .denied(let reason):
                throw OAuthError.authorizationDenied(reason)
            case .expired:
                throw OAuthError.deviceCodeExpired
            }
        }

        throw OAuthError.deviceCodeExpired
    }

    private enum DeviceCodePollOutcome {
        case authorized(OAuthCredential)
        case pending
        case slowDown(Int?)
        case denied(String)
        case expired
    }

    private func pollDeviceCodeOnce(
        provider: some OAuthProvider,
        deviceCode: String
    ) async throws -> DeviceCodePollOutcome {
        guard let url = URL(string: provider.tokenURL) else {
            throw OAuthError.tokenExchangeFailed("Invalid token URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded([
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            "client_id": provider.clientId,
            "device_code": deviceCode
        ]).data(using: .utf8)

        let data: Data
        do {
            data = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny).0
        } catch NetworkError.transport(let underlying) where (underlying as? URLError)?.code == .cancelled {
            // The user cancelled mid-request. Report it as cancellation so the
            // caller can stay silent instead of raising a network error.
            throw CancellationError()
        } catch NetworkError.transport(let underlying) {
            // Transient failure (commonly -1005 right after backgrounding);
            // treat as pending and retry on the next tick.
            logger.logInfo("Device-code poll network error, retrying: \(underlying.localizedDescription)")
            return .pending
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .pending
        }

        if let error = json["error"] as? String {
            switch error {
            case "authorization_pending":
                return .pending
            case "slow_down":
                return .slowDown(json["interval"] as? Int)
            case "access_denied", "authorization_denied":
                return .denied(Self.errorDetail(json) ?? "Authorization was denied")
            case "expired_token":
                return .expired
            default:
                throw OAuthError.tokenExchangeFailed(Self.errorDetail(json) ?? error)
            }
        }

        let credential = try await buildCredential(json: json, provider: provider, existingRefreshToken: nil)
        return .authorized(credential)
    }

    // MARK: - Request Helpers

    /// Percent-encodes values against RFC 3986's *unreserved* set, so reserved
    /// characters that carry meaning in a form body (`&`, `=`, `+`, spaces) are
    /// escaped. `.urlQueryAllowed` would let those through intact.
    private static let unreservedCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func formEncoded(_ fields: [String: String]) -> String {
        fields.map { key, value in
            let encoded = value.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? value
            return "\(key)=\(encoded)"
        }
        .joined(separator: "&")
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String, !string.isEmpty else { return nil }
        return string
    }

    /// Rejects anything that isn't an `https` URL. The result is handed to the
    /// system opener, so a non-https scheme here would let a compromised or
    /// spoofed response launch an arbitrary handler.
    private static func validatedHTTPSURI(_ raw: String) -> String? {
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil else {
            return nil
        }
        return url.absoluteString
    }

    private static func errorDetail(_ json: [String: Any]) -> String? {
        let error = json["error"] as? String
        let description = json["error_description"] as? String
        let detail = [error, description].compactMap { $0 }.joined(separator: ": ")
        return detail.isEmpty ? nil : detail
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
                var refreshed = try await tokenRequest(body: body, provider: provider, existingRefreshToken: credential.refreshToken)
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

    private func tokenRequest(body: [String: String], provider: some OAuthProvider, existingRefreshToken: String? = nil) async throws -> OAuthCredential {
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

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthError.tokenExchangeFailed("Invalid JSON response")
        }

        return try await buildCredential(json: json, provider: provider, existingRefreshToken: existingRefreshToken)
    }

    /// Turns a successful token-endpoint payload into a stored-shape credential.
    /// Shared by the redirect flow, the device-code flow, and refresh.
    private func buildCredential(
        json: [String: Any],
        provider: some OAuthProvider,
        existingRefreshToken: String?
    ) async throws -> OAuthCredential {
        guard let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
            throw OAuthError.tokenExchangeFailed("Missing access token in response")
        }
        // Google's refresh endpoint omits refresh_token, and xAI omits it when the
        // token is not rotated - fall back to the existing one in both cases.
        let refreshToken = json["refresh_token"] as? String ?? existingRefreshToken ?? ""

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
        } else if let claims = OpenAIOAuthProvider.decodeJWTPayload(accessToken) {
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

        guard let (data, httpResponse) = try? await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny),
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
            keychain.save(data: data, forKey: provider.keychainKey, syncable: false)
        }
    }

    private func loadCredential(for provider: some OAuthProvider) -> OAuthCredential? {
        // Check in-memory cache first
        if let cached = credentials[provider.keychainKey] {
            return cached
        }

        // Load from Keychain
        guard let data = keychain.getData(forKey: provider.keychainKey, syncable: false),
              let credential = try? JSONDecoder().decode(OAuthCredential.self, from: data) else {
            return nil
        }

        // Don't return expired credentials with no way to refresh
        if credential.isExpired && credential.refreshToken.isEmpty {
            keychain.delete(forKey: provider.keychainKey, syncable: false)
            return nil
        }

        credentials[provider.keychainKey] = credential
        return credential
    }
}
