// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Google Gemini OAuth provider configuration.
/// Uses the same client ID as the Gemini CLI for OAuth PKCE flow.
/// After authentication, discovers a Google Cloud project via Code Assist API.
struct GeminiOAuthProvider: OAuthProvider {
    let providerName = "Gemini"
    let clientId = "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com"
    let clientSecret: String? = "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"
    let authorizeURL = "https://accounts.google.com/o/oauth2/v2/auth"
    let tokenURL = "https://oauth2.googleapis.com/token"
    let redirectURI = "http://localhost:8085/oauth2callback"
    let scopes = "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile"
    let keychainKey = "geminiOAuthCredential"
    let userinfoURL: String? = "https://www.googleapis.com/oauth2/v3/userinfo"

    let extraAuthParams: [String: String] = [
        "access_type": "offline",
        "prompt": "consent"
    ]

    func extractAccountInfo(from claims: [String: Any]) -> (id: String?, email: String?) {
        let id = claims["sub"] as? String
        let email = claims["email"] as? String
        return (id, email)
    }

    // MARK: - Code Assist Project Discovery

    private static let logger = Logger(category: .oauthManager)
    private static let codeAssistEndpoint = "https://cloudcode-pa.googleapis.com"

    func postAuthSetup(accessToken: String) async throws -> String? {
        // Step 1: Try to load existing Code Assist project
        if let projectId = try? await loadCodeAssist(accessToken: accessToken) {
            Self.logger.logInfo("Gemini: found existing project \(projectId)")
            return projectId
        }

        // Step 2: Onboard user if no project exists
        Self.logger.logInfo("Gemini: no project found, onboarding user")
        if let projectId = try? await onboardUser(accessToken: accessToken) {
            Self.logger.logInfo("Gemini: onboarded, project \(projectId)")
            return projectId
        }

        Self.logger.logWarning("Gemini: project discovery failed, continuing without projectId")
        return nil
    }

    private func loadCodeAssist(accessToken: String) async throws -> String? {
        guard let url = URL(string: "\(Self.codeAssistEndpoint)/v1internal:loadCodeAssist") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "metadata": [
                "ideType": "IDE_UNSPECIFIED",
                "platform": "PLATFORM_UNSPECIFIED",
                "pluginType": "GEMINI"
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projectId = json["cloudaicompanionProject"] as? String else {
            return nil
        }

        return projectId
    }

    private func onboardUser(accessToken: String) async throws -> String? {
        guard let url = URL(string: "\(Self.codeAssistEndpoint)/v1internal:onboardUser") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = ["tierId": "free-tier"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Check if it's a long-running operation
        if let operationName = json["name"] as? String {
            return try? await pollOperation(name: operationName, accessToken: accessToken)
        }

        return json["cloudaicompanionProject"] as? String
    }

    private func pollOperation(name: String, accessToken: String) async throws -> String? {
        guard let url = URL(string: "\(Self.codeAssistEndpoint)/v1internal/\(name)") else { return nil }

        // Poll up to 10 times with 2s intervals
        for _ in 0..<10 {
            try await Task.sleep(for: .seconds(2))

            var request = URLRequest(url: url)
            request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let done = json["done"] as? Bool, done,
               let result = json["response"] as? [String: Any],
               let projectId = result["cloudaicompanionProject"] as? String {
                return projectId
            }
        }

        return nil
    }
}
