//
//  ExaWebSearchTool.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import Foundation
import FoundationModels

/// Apple FM tool that searches the web using the Exa API.
///
/// The model decides when to call this tool during chat to answer
/// questions that require current information beyond the note text.
@available(iOS 26, *)
struct ExaWebSearchTool: Tool {
    let name = "searchWeb"
    let description = "Search the web ONLY when the user explicitly asks to look something up online, or asks about current events, news, or real-time facts. Do NOT use this tool to answer questions about the user's notes - those are already in the conversation."

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    @Generable
    struct Arguments: Sendable {
        @Guide(description: "The search query to look up on the web")
        var query: String
    }

    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        let query = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return ExaAPIClient.formatError("Search query cannot be empty.")
        }

        do {
            let results = try await ExaAPIClient.search(query: query, apiKey: apiKey)
            return ExaAPIClient.formatResults(query: query, results: results)
        } catch {
            return ExaAPIClient.formatError("Web search failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - API Client (nonisolated for Tool protocol compatibility)

@available(iOS 26, *)
nonisolated enum ExaAPIClient: Sendable {
    nonisolated static func search(query: String, apiKey: String) async throws -> [ExaResult] {
        guard let url = URL(string: "https://api.exa.ai/search") else {
            throw ExaError.invalidURL
        }

        let payload = ExaRequest(
            query: query,
            numResults: 5,
            contents: ExaContents(text: ExaTextOptions(maxCharacters: 500))
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExaError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ExaError.httpStatus(code: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(ExaResponse.self, from: data).results
    }

    nonisolated static func formatResults(query: String, results: [ExaResult]) -> GeneratedContent {
        if results.isEmpty {
            return GeneratedContent(properties: [
                "status": "empty",
                "query": query,
                "summary": "No results found for \"\(query)\"."
            ])
        }

        let summary = results.prefix(5).enumerated().map { index, result in
            let snippet = result.text ?? "No content available."
            return """
            \(index + 1). \(result.title ?? "Untitled")
            \(snippet)
            URL: \(result.url)
            """
        }.joined(separator: "\n\n")

        return GeneratedContent(properties: [
            "status": "success",
            "query": query,
            "summary": summary
        ])
    }

    nonisolated static func formatError(_ message: String) -> GeneratedContent {
        GeneratedContent(properties: [
            "status": "error",
            "summary": message
        ])
    }
}

// MARK: - API Models

nonisolated struct ExaRequest: Encodable, Sendable {
    let query: String
    let numResults: Int
    let contents: ExaContents
}

nonisolated struct ExaContents: Encodable, Sendable {
    let text: ExaTextOptions
}

nonisolated struct ExaTextOptions: Encodable, Sendable {
    let maxCharacters: Int
}

nonisolated struct ExaResponse: Decodable, Sendable {
    let results: [ExaResult]
}

nonisolated struct ExaResult: Decodable, Sendable {
    let title: String?
    let url: String
    let text: String?
    let publishedDate: String?
}

private enum ExaError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid Exa API URL."
        case .invalidResponse: "Invalid response from Exa API."
        case let .httpStatus(code):
            switch code {
            case 401, 403: "Invalid Exa API key."
            case 429: "Exa API rate limit exceeded. Try again later."
            default: "Exa API returned HTTP \(code)."
            }
        }
    }
}

// MARK: - API Key Helper

enum ExaAPIKeyManager {
    static let keychainKey = "exaAPIKey"

    static var apiKey: String? {
        KeychainService.shared.getString(forKey: keychainKey)
    }

    static var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        KeychainService.shared.save(key, forKey: keychainKey)
    }

    @discardableResult
    static func delete() -> Bool {
        KeychainService.shared.delete(forKey: keychainKey)
    }
}
