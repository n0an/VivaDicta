//
//  ClaudeCLIServerClient.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.25
//

import Foundation

enum ClaudeCLIServerClient {

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

    static let claudeCliAvailableKey = "cliServer_claudeAvailable"
    static let codexCliAvailableKey = "cliServer_codexAvailable"
    static let geminiCliAvailableKey = "cliServer_geminiAvailable"

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

    static var isClaudeCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: claudeCliAvailableKey)
    }

    static var isCodexCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: codexCliAvailableKey)
    }

    static var isGeminiCliAvailable: Bool {
        UserDefaults.standard.bool(forKey: geminiCliAvailableKey)
    }

    static func saveAvailability(from health: HealthResponse) {
        UserDefaults.standard.set(health.claudeAvailable, forKey: claudeCliAvailableKey)
        UserDefaults.standard.set(health.codexAvailable ?? false, forKey: codexCliAvailableKey)
        UserDefaults.standard.set(health.geminiAvailable ?? false, forKey: geminiCliAvailableKey)
    }

    static func clearAvailability() {
        UserDefaults.standard.set(false, forKey: claudeCliAvailableKey)
        UserDefaults.standard.set(false, forKey: codexCliAvailableKey)
        UserDefaults.standard.set(false, forKey: geminiCliAvailableKey)
    }

    // MARK: - Enhance

    static func enhance(
        text: String,
        systemPrompt: String,
        model: String,
        provider: String = "claude"
    ) async throws -> String {
        guard let baseURL = serverURL, !baseURL.isEmpty else {
            throw ClaudeCLIServerError.invalidURL
        }

        let urlString = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/enhance"
        guard let url = URL(string: urlString) else {
            throw ClaudeCLIServerError.invalidURL
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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeCLIServerError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let result = try JSONDecoder().decode(EnhanceResponse.self, from: data)
            return result.result
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ClaudeCLIServerError.serverError(errorResponse.error)
            }
            throw ClaudeCLIServerError.httpError(httpResponse.statusCode)
        }
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

    static func testConnection(provider: String = "claude") async -> Bool {
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
            case "claude": return health.claudeAvailable
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

enum ClaudeCLIServerError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Claude CLI Server URL."
        case .invalidResponse:
            "Invalid response from Claude CLI server."
        case .serverError(let message):
            message
        case .httpError(let code):
            "Claude CLI server returned HTTP \(code)."
        }
    }
}
