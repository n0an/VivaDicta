// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os

/// Pure HTTP wrapper for the local Ollama server's model-discovery and
/// connection-check endpoints. Stateless apart from its dependencies.
///
/// Lives in the app target as the first step of the AIService decomposition
/// (Phase 2a of the architecture migration). `AIService` retains ownership
/// of the `@Observable` `ollamaModels` state and the user-configurable
/// `ollamaServerURL`; `OllamaService` just runs the HTTP calls and returns
/// values.
///
/// ## Endpoints
///
/// Ollama exposes two compatible APIs:
/// - **OpenAI-compatible:** `GET /v1/models` returns `{"data": [{"id": "..."}]}`
/// - **Native:** `GET /api/tags` returns `{"models": [{"name": "..."}]}`
///
/// `fetchModels` tries the OpenAI-compatible endpoint first and falls back
/// to the native endpoint. `checkConnection` always uses the native endpoint
/// because that one is guaranteed to exist on every Ollama install.
struct OllamaService: Sendable {
    private let networkService: any NetworkService
    private let logger: Logger

    init(networkService: any NetworkService, logger: Logger) {
        self.networkService = networkService
        self.logger = logger
    }

    /// Fetches the list of model names available on the Ollama server.
    /// Tries the OpenAI-compatible endpoint first; falls back to the native
    /// `/api/tags` endpoint if that fails or returns non-200.
    ///
    /// Returns the (sorted) model names. Throws only if both endpoints fail
    /// to produce a usable response.
    func fetchModels(serverURL: String) async throws -> [String] {
        do {
            return try await fetchModelsViaOpenAICompatibleEndpoint(serverURL: serverURL)
        } catch {
            logger.logWarning("Failed to fetch Ollama models via OpenAI-compatible endpoint: \(error.localizedDescription); trying native endpoint")
            return try await fetchModelsViaNativeEndpoint(serverURL: serverURL)
        }
    }

    /// Lightweight reachability check. Pings the native `/api/tags` endpoint
    /// with a 3s timeout. Returns `false` for any non-200 / transport error,
    /// never throws.
    func checkConnection(serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/api/tags") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3

        do {
            let (_, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)
            return httpResponse.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Private endpoint helpers

    private func fetchModelsViaOpenAICompatibleEndpoint(serverURL: String) async throws -> [String] {
        // `URL(string:)` is intentionally permissive here. If the user-typed
        // serverURL is malformed enough that URLSession can't reach it, the
        // request below throws a URLError which propagates to the caller's
        // fallback / catch.
        let url = URL(string: "\(serverURL)/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard httpResponse.statusCode == 200 else {
            logger.logWarning("Ollama OpenAI-compatible endpoint returned \(httpResponse.statusCode); will try native endpoint")
            throw OllamaServiceError.unexpectedStatus(httpResponse.statusCode)
        }

        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = jsonResponse["data"] as? [[String: Any]] else {
            logger.logError("Failed to parse Ollama OpenAI-compatible models response")
            throw OllamaServiceError.malformedResponse
        }

        let models = dataArray.compactMap { $0["id"] as? String }.sorted()
        logger.logInfo("Fetched \(models.count) Ollama models via OpenAI-compatible endpoint")
        return models
    }

    private func fetchModelsViaNativeEndpoint(serverURL: String) async throws -> [String] {
        let url = URL(string: "\(serverURL)/api/tags")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5

        let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

        guard httpResponse.statusCode == 200 else {
            logger.logError("Ollama native endpoint returned \(httpResponse.statusCode)")
            throw OllamaServiceError.unexpectedStatus(httpResponse.statusCode)
        }

        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = jsonResponse["models"] as? [[String: Any]] else {
            logger.logError("Failed to parse Ollama native models response")
            throw OllamaServiceError.malformedResponse
        }

        let models = modelsArray.compactMap { $0["name"] as? String }.sorted()
        logger.logInfo("Fetched \(models.count) Ollama models via native endpoint")
        return models
    }
}

enum OllamaServiceError: Error, Equatable {
    case unexpectedStatus(Int)
    case malformedResponse
}
