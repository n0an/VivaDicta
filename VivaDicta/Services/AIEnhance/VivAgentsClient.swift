//
//  VivAgentsClient.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.25
//

import Foundation
import os

enum VivAgentsClient {

    private static let logger = Logger(category: .vivAgentsClient)

    struct EnhanceRequest: Encodable {
        let text: String
        let systemPrompt: String
        let model: String
        let provider: String
    }

    struct EnhanceResponse: Decodable {
        let result: String
        let model: String?
        let duration: Double?
    }

    struct ErrorResponse: Decodable {
        let error: String
        let code: String?
    }

    struct HealthResponse: Decodable {
        let status: String
        let claudeAvailable: Bool
        let claudePath: String?
        let codexAvailable: Bool?
        let codexPath: String?
        let geminiAvailable: Bool?
        let geminiPath: String?
        let version: String?

        enum CodingKeys: String, CodingKey {
            case status
            case claudeAvailable = "claude_available"
            case claudePath = "claude_path"
            case codexAvailable = "codex_available"
            case codexPath = "codex_path"
            case geminiAvailable = "gemini_available"
            case geminiPath = "gemini_path"
            case version
        }
    }

    // MARK: - UserDefaults Keys

    static let isEnabledKey = "isClaudeCLIServerClientEnabled"
    static let serverURLKey = "claudeCLIServerClientURL"
    static let isVerifiedKey = "isClaudeCLIServerClientVerified"

    // MARK: - Per-CLI Availability Keys

    static let anthropicCliAvailableKey = "cliServer_claudeAvailable"
    static let codexCliAvailableKey = "cliServer_codexAvailable"
    static let geminiCliAvailableKey = "cliServer_geminiAvailable"

    // MARK: - Per-Provider Enable Keys (user preference on iOS)

    static let anthropicCliEnabledKey = "cliServer_claudeEnabled"
    static let codexCliEnabledKey = "cliServer_codexEnabled"
    static let geminiCliEnabledKey = "cliServer_geminiEnabled"

    // MARK: - Keychain Keys

    static let authTokenKeychainKey = "claudeCLIServerClientToken"

    // MARK: - Configuration

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: isEnabledKey)
    }

    static var serverURL: String? {
        UserDefaults.standard.string(forKey: serverURLKey)
    }

    static var authToken: String? {
        KeychainService.shared.getString(forKey: authTokenKeychainKey, syncable: false)
    }

    static var isVerified: Bool {
        UserDefaults.standard.bool(forKey: isVerifiedKey)
    }

    static var isAnthropicCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: anthropicCliAvailableKey)
    }

    static var isCodexCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: codexCliAvailableKey)
    }

    static var isGeminiCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: geminiCliAvailableKey)
    }

    // Per-provider user preference (defaults to true)
    static var isAnthropicCliEnabled: Bool {
        UserDefaults.standard.object(forKey: anthropicCliEnabledKey) == nil || UserDefaults.standard.bool(forKey: anthropicCliEnabledKey)
    }

    static var isCodexCliEnabled: Bool {
        UserDefaults.standard.object(forKey: codexCliEnabledKey) == nil || UserDefaults.standard.bool(forKey: codexCliEnabledKey)
    }

    static var isGeminiCliEnabled: Bool {
        UserDefaults.standard.object(forKey: geminiCliEnabledKey) == nil || UserDefaults.standard.bool(forKey: geminiCliEnabledKey)
    }

    /// Whether a specific CLI agent is both available on server AND enabled by user
    static var isAnthropicCliActive: Bool { isAnthropicCliAvailable && isAnthropicCliEnabled }
    static var isCodexCliActive: Bool { isCodexCliAvailable && isCodexCliEnabled }
    static var isGeminiCliActive: Bool { isGeminiCliAvailable && isGeminiCliEnabled }

    static func saveAvailability(from health: HealthResponse) {
        UserDefaults.standard.set(health.claudeAvailable, forKey: anthropicCliAvailableKey)
        UserDefaults.standard.set(health.codexAvailable ?? false, forKey: codexCliAvailableKey)
        UserDefaults.standard.set(health.geminiAvailable ?? false, forKey: geminiCliAvailableKey)
    }

    static func clearAvailability() {
        UserDefaults.standard.set(false, forKey: anthropicCliAvailableKey)
        UserDefaults.standard.set(false, forKey: codexCliAvailableKey)
        UserDefaults.standard.set(false, forKey: geminiCliAvailableKey)
    }

    // MARK: - Enhance

    static func enhance(
        text: String,
        systemPrompt: String,
        model: String,
        provider: String = "anthropic"
    ) async throws -> String {
        guard let baseURL = serverURL, !baseURL.isEmpty else {
            throw VivAgentsClientError.invalidURL
        }

        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/process"
        guard let url = URL(string: urlString) else {
            throw VivAgentsClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        if let token = authToken, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = EnhanceRequest(text: text, systemPrompt: systemPrompt, model: model, provider: provider)
        request.httpBody = try JSONEncoder().encode(body)

        logger.logInfo("VivAgents request: provider=\(provider), model=\(model), textLength=\(text.count)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.logError("VivAgents: invalid response (not HTTP)")
            throw VivAgentsClientError.invalidResponse
        }

        logger.logInfo("VivAgents response: HTTP \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(EnhanceResponse.self, from: data)
            logger.logInfo("VivAgents success: resultLength=\(result.result.count), duration=\(result.duration ?? 0)s")
            return result.result
        } else {
            let rawBody = String(data: data, encoding: .utf8) ?? "(non-UTF8 body)"
            logger.logError("VivAgents error: HTTP \(httpResponse.statusCode), body=\(rawBody)")

            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                let message = Self.humanReadableError(errorResponse.error, code: errorResponse.code, httpStatus: httpResponse.statusCode, provider: provider)
                throw VivAgentsClientError.serverError(message)
            }
            throw VivAgentsClientError.httpError(httpResponse.statusCode)
        }
    }

    /// Maps raw server errors to user-friendly messages
    private static func humanReadableError(_ message: String, code: String?, httpStatus: Int, provider: String) -> String {
        let lowered = message.lowercased()

        // Rate limiting
        if httpStatus == 429 || lowered.contains("rate limit") || lowered.contains("too many requests") || lowered.contains("overloaded") {
            let providerName = switch provider {
            case "codex": "Codex"
            case "gemini": "Gemini"
            default: "Anthropic"
            }
            return "\(providerName) CLI rate limit reached. Please wait a moment and try again."
        }

        // CLI not available / disabled
        if lowered.contains("sharing is disabled") || lowered.contains("not available") || lowered.contains("not found") {
            return message
        }

        // Invalid JSON from CLI
        if lowered.contains("invalid json") {
            let providerName = switch provider {
            case "codex": "Codex"
            case "gemini": "Gemini"
            default: "Anthropic"
            }
            return "\(providerName) CLI returned an invalid response. This may be a temporary issue — please try again."
        }

        return message
    }

    // MARK: - Test Connection

    static func fetchHealth() async -> HealthResponse? {
        guard let baseURL = serverURL, !baseURL.isEmpty else { return nil }

        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        if let token = authToken, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(HealthResponse.self, from: data)
        } catch {
            return nil
        }
    }

    static func testConnection(provider: String = "anthropic") async -> Bool {
        guard let baseURL = serverURL, !baseURL.isEmpty else { return false }

        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/health"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        if let token = authToken, !token.isEmpty {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return false }
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            switch provider {
            case "codex": return health.codexAvailable ?? false
            case "gemini": return health.geminiAvailable ?? false
            case "anthropic": return health.claudeAvailable
            default:
                // No specific provider — succeed if any CLI is available
                return health.claudeAvailable
                    || (health.codexAvailable ?? false)
                    || (health.geminiAvailable ?? false)
            }
        } catch {
            return false
        }
    }

}

enum VivAgentsClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid VivAgents server URL."
        case .invalidResponse:
            "Invalid response from VivAgents server."
        case .serverError(let message):
            message
        case .httpError(let code):
            "VivAgents server returned HTTP \(code)."
        }
    }
}
