// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Keychain
import os

/// Manages GitHub Copilot authentication using the device code flow.
/// Two-step process: GitHub device code -> Copilot token exchange.
@MainActor
public final class CopilotOAuthManager: Sendable {
    private let logger = Logger(oauthCategory: "CopilotOAuth")
    private let keychain: any KeychainServicing
    private let backgroundTaskService: (any BackgroundTaskServicing)?

    /// GitHub OAuth client ID (same as VS Code Copilot extension).
    private let clientId = "Iv1.b507a08c87ecfe98"
    private let deviceCodeURL = "https://github.com/login/device/code"
    private let accessTokenURL = "https://github.com/login/oauth/access_token"
    private let copilotTokenURL = "https://api.github.com/copilot_internal/v2/token"
    private let keychainKey = "copilotOAuthCredential"

    private var credential: CopilotCredential?

    public init(
        keychain: any KeychainServicing,
        backgroundTaskService: (any BackgroundTaskServicing)? = nil
    ) {
        self.keychain = keychain
        self.backgroundTaskService = backgroundTaskService
    }

    // MARK: - Public API

    public var isSignedIn: Bool {
        loadCredential() != nil
    }

    public var accountInfo: String? {
        loadCredential()?.githubUsername
    }

    /// Starts the device code flow. Returns the user code and verification URI.
    public func startDeviceCodeFlow() async throws -> DeviceCodeResponse {
        guard let url = URL(string: deviceCodeURL) else {
            throw CopilotOAuthError.deviceCodeFailed("Invalid device code URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "client_id=\(clientId)&scope=read:user".data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CopilotOAuthError.deviceCodeFailed("Failed to get device code")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationUri = json["verification_uri"] as? String,
              let interval = json["interval"] as? Int else {
            throw CopilotOAuthError.deviceCodeFailed("Invalid device code response")
        }

        let expiresIn = json["expires_in"] as? Int ?? 900

        return DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationUri: verificationUri,
            interval: interval,
            expiresIn: expiresIn
        )
    }

    /// Polls GitHub until the user authorizes the device code.
    public func pollForToken(deviceCode: String, interval: Int, expiresIn: Int = 900) async throws -> CopilotCredential {
        let pollInterval = max(interval, 5)
        let maxAttempts = expiresIn / pollInterval

        // Keep polling alive for ~30s while Safari is foregrounded for the device-code prompt.
        let bgTaskId = backgroundTaskService?.beginBackgroundTask(name: "CopilotOAuthPoll", onExpiration: {})
        defer {
            if let bgTaskId {
                backgroundTaskService?.endBackgroundTask(bgTaskId)
            }
        }

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try await Task.sleep(for: .seconds(pollInterval))
            }

            guard let tokenURL = URL(string: accessTokenURL) else {
                throw CopilotOAuthError.tokenExchangeFailed("Invalid token URL")
            }
            var request = URLRequest(url: tokenURL)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)

            let data: Data
            do {
                data = try await URLSession.shared.data(for: request).0
            } catch let urlError as URLError where urlError.code != .cancelled {
                // Transient network error (e.g. -1005 after backgrounding); retry on next tick.
                logger.logInfo("Poll network error \(urlError.code.rawValue), retrying")
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let error = json["error"] as? String {
                switch error {
                case "authorization_pending":
                    continue
                case "slow_down":
                    try await Task.sleep(for: .seconds(pollInterval + 5))
                    continue
                case "expired_token":
                    throw CopilotOAuthError.timeout
                case "access_denied":
                    throw CopilotOAuthError.accessDenied
                default:
                    continue
                }
            }

            if let accessToken = json["access_token"] as? String {
                logger.logInfo("GitHub access token obtained")

                let username = await fetchGitHubUsername(accessToken: accessToken)
                let copilotToken = try await exchangeForCopilotToken(githubToken: accessToken)

                let cred = CopilotCredential(
                    githubAccessToken: accessToken,
                    copilotToken: copilotToken.token,
                    copilotTokenExpiresAt: copilotToken.expiresAt,
                    githubUsername: username
                )

                saveCredential(cred)
                logger.logInfo("Copilot sign-in complete")
                return cred
            }
        }

        throw CopilotOAuthError.timeout
    }

    /// Returns a valid Copilot token, refreshing if needed.
    public func validCopilotToken() async throws -> String {
        guard var cred = loadCredential() else {
            throw CopilotOAuthError.noCredential
        }

        if Date().addingTimeInterval(300) >= cred.copilotTokenExpiresAt {
            logger.logInfo("Copilot token expiring soon, refreshing")
            let newToken = try await exchangeForCopilotToken(githubToken: cred.githubAccessToken)
            cred = CopilotCredential(
                githubAccessToken: cred.githubAccessToken,
                copilotToken: newToken.token,
                copilotTokenExpiresAt: newToken.expiresAt,
                githubUsername: cred.githubUsername
            )
            saveCredential(cred)
        }

        return cred.copilotToken
    }

    public func signOut() {
        credential = nil
        keychain.delete(forKey: keychainKey, syncable: false)
        logger.logInfo("Signed out from GitHub Copilot")
    }

    // MARK: - Copilot Token Exchange

    private func exchangeForCopilotToken(githubToken: String) async throws -> (token: String, expiresAt: Date) {
        guard let url = URL(string: copilotTokenURL) else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        request.addValue("GitHubCopilotChat/0.35.0", forHTTPHeaderField: "User-Agent")
        request.addValue("vscode/1.107.0", forHTTPHeaderField: "Editor-Version")
        request.addValue("copilot-chat/0.35.0", forHTTPHeaderField: "Editor-Plugin-Version")
        request.addValue("vscode-chat", forHTTPHeaderField: "Copilot-Integration-Id")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.logError("Copilot token exchange failed: HTTP \(httpResponse.statusCode) - \(body)")
            if httpResponse.statusCode == 401 {
                throw CopilotOAuthError.noCopilotSubscription
            }
            throw CopilotOAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let expiresAt = json["expires_at"] as? Int else {
            throw CopilotOAuthError.tokenExchangeFailed("Invalid response format")
        }

        return (token, Date(timeIntervalSince1970: TimeInterval(expiresAt)))
    }

    // MARK: - GitHub User Info

    private func fetchGitHubUsername(accessToken: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/user") else { return nil }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json["login"] as? String
    }

    // MARK: - Credential Storage

    private func saveCredential(_ cred: CopilotCredential) {
        credential = cred
        if let data = try? JSONEncoder().encode(cred) {
            keychain.save(data: data, forKey: keychainKey, syncable: false)
        }
    }

    private func loadCredential() -> CopilotCredential? {
        if let cached = credential { return cached }

        guard let data = keychain.getData(forKey: keychainKey, syncable: false),
              let cred = try? JSONDecoder().decode(CopilotCredential.self, from: data) else {
            return nil
        }

        credential = cred
        return cred
    }
}

// MARK: - Models

public struct CopilotCredential: Codable, Sendable {
    public let githubAccessToken: String
    public let copilotToken: String
    public let copilotTokenExpiresAt: Date
    public let githubUsername: String?

    public init(
        githubAccessToken: String,
        copilotToken: String,
        copilotTokenExpiresAt: Date,
        githubUsername: String?
    ) {
        self.githubAccessToken = githubAccessToken
        self.copilotToken = copilotToken
        self.copilotTokenExpiresAt = copilotTokenExpiresAt
        self.githubUsername = githubUsername
    }
}

public struct DeviceCodeResponse: Sendable {
    public let deviceCode: String
    public let userCode: String
    public let verificationUri: String
    public let interval: Int
    public let expiresIn: Int

    public init(
        deviceCode: String,
        userCode: String,
        verificationUri: String,
        interval: Int,
        expiresIn: Int
    ) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationUri = verificationUri
        self.interval = interval
        self.expiresIn = expiresIn
    }
}

// MARK: - Errors

public enum CopilotOAuthError: LocalizedError {
    case deviceCodeFailed(String)
    case timeout
    case accessDenied
    case tokenExchangeFailed(String)
    case noCopilotSubscription
    case noCredential

    public var errorDescription: String? {
        switch self {
        case .deviceCodeFailed(let reason):
            return "Failed to start sign-in: \(reason)"
        case .timeout:
            return "Sign-in timed out. Please try again."
        case .accessDenied:
            return "Authorization was denied."
        case .tokenExchangeFailed(let reason):
            return "Failed to get Copilot token: \(reason)"
        case .noCopilotSubscription:
            return "No active GitHub Copilot subscription found."
        case .noCredential:
            return "Not signed in to GitHub Copilot."
        }
    }
}
