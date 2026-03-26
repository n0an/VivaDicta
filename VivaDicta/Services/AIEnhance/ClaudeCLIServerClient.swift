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

        enum CodingKeys: String, CodingKey {
            case status
            case claudeAvailable = "claude_available"
            case claudePath = "claude_path"
        }
    }

    // MARK: - UserDefaults Keys

    static let isEnabledKey = "isClaudeCLIServerClientEnabled"
    static let serverURLKey = "claudeCLIServerClientURL"
    static let isVerifiedKey = "isClaudeCLIServerClientVerified"

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

    // MARK: - Enhance

    static func enhance(
        text: String,
        systemPrompt: String,
        model: String
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

        let body = EnhanceRequest(text: text, systemPrompt: systemPrompt, model: model)
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

    static func testConnection() async -> Bool {
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
            return health.claudeAvailable
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
