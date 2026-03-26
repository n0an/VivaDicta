// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Manages GitHub Copilot authentication using the device code flow.
/// Two-step process: GitHub device code → Copilot token exchange.
@MainActor
final class CopilotOAuthManager: Sendable {
    static let shared = CopilotOAuthManager()

    private let logger = Logger(category: .copilotOAuth)

    /// GitHub OAuth client ID (same as VS Code Copilot extension).
    private let clientId = "Iv1.b507a08c87ecfe98"
    private let deviceCodeURL = "https://github.com/login/device/code"
    private let accessTokenURL = "https://github.com/login/oauth/access_token"
    private let copilotTokenURL = "https://api.github.com/copilot_internal/v2/token"
    private let keychainKey = "copilotOAuthCredential"

    private var credential: CopilotCredential?

    private init() {}

    // MARK: - Public API

    var isSignedIn: Bool {
        loadCredential() != nil
    }

    var accountInfo: String? {
        loadCredential()?.githubUsername
    }

    /// Starts the device code flow. Returns the user code and verification URI.
    func startDeviceCodeFlow() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: URL(string: deviceCodeURL)!)
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
    func pollForToken(deviceCode: String, interval: Int) async throws -> CopilotCredential {
        let pollInterval = max(interval, 5)
        let maxAttempts = 180 / pollInterval

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try await Task.sleep(for: .seconds(pollInterval))
            }

            var request = URLRequest(url: URL(string: accessTokenURL)!)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code".data(using: .utf8)

            let (data, _) = try await URLSession.shared.data(for: request)

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
    func validCopilotToken() async throws -> String {
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

    func signOut() {
        credential = nil
        KeychainService.shared.delete(forKey: keychainKey, syncable: false)
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
            logger.logError("Copilot token exchange failed: HTTP \(httpResponse.statusCode) — \(body)")
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
            KeychainService.shared.save(data: data, forKey: keychainKey, syncable: false)
        }
    }

    private func loadCredential() -> CopilotCredential? {
        if let cached = credential { return cached }

        guard let data = KeychainService.shared.getData(forKey: keychainKey, syncable: false),
              let cred = try? JSONDecoder().decode(CopilotCredential.self, from: data) else {
            return nil
        }

        credential = cred
        return cred
    }
}

// MARK: - Models

struct CopilotCredential: Codable, Sendable {
    let githubAccessToken: String
    let copilotToken: String
    let copilotTokenExpiresAt: Date
    let githubUsername: String?
}

struct DeviceCodeResponse: Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let interval: Int
    let expiresIn: Int
}

// MARK: - Errors

enum CopilotOAuthError: LocalizedError {
    case deviceCodeFailed(String)
    case timeout
    case accessDenied
    case tokenExchangeFailed(String)
    case noCopilotSubscription
    case noCredential

    var errorDescription: String? {
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
