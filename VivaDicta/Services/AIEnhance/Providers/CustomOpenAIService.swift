// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import os

/// Pure HTTP wrapper for testing a user-configured "Custom OpenAI"
/// endpoint. Stateless apart from its dependencies.
///
/// Lives in the app target alongside `OllamaService` as the second step of
/// the AIService decomposition (Phase 2a of the architecture migration).
/// `AIService` retains ownership of the `@Observable` configuration state
/// (`customOpenAIEndpointURL`, `customOpenAIModelName`,
/// `customOpenAIIsVerified`); this struct just runs the HTTP probe and
/// returns a structured result.
///
/// ## Endpoint shape
///
/// Sends a minimal `POST <endpoint>` request with an OpenAI-compatible
/// chat-completions body (model + one-message conversation: `[{ "role":
/// "user", "content": "test" }]`). Verifies the endpoint responds with
/// `200`; maps other status codes and `URLError` cases to user-readable
/// failure messages so the settings UI can surface them directly.
struct CustomOpenAIService: Sendable {
    /// Structured outcome of a Custom OpenAI endpoint test. Either side
    /// carries a user-facing message suitable for display in the settings
    /// UI.
    enum TestResult: Equatable, Sendable {
        case success(message: String)
        case failure(message: String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }

        var message: String {
            switch self {
            case let .success(message), let .failure(message):
                return message
            }
        }
    }

    private let networkService: any NetworkService
    private let logger: Logger

    init(networkService: any NetworkService, logger: Logger) {
        self.networkService = networkService
        self.logger = logger
    }

    /// Probes a Custom OpenAI endpoint with a minimal chat-completions
    /// request and returns a structured result. Never throws - all errors
    /// (URLError, bad status, bad body) map to `.failure(message:)`.
    func testEndpoint(
        endpointURL: String,
        modelName: String,
        apiKey: String?
    ) async -> TestResult {
        logger.logNotice("Custom OpenAI test - URL: '\(endpointURL)', model: '\(modelName)'")

        guard let url = URL(string: endpointURL) else {
            logger.logError("Custom OpenAI test - invalid URL: '\(endpointURL)'")
            return .failure(message: "Invalid endpoint URL format")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let hasAPIKey = apiKey?.isEmpty == false
        logger.logNotice("Custom OpenAI test - API Key present: \(hasAPIKey)")
        if let apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let testBody: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "user", "content": "test"]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: testBody) else {
            logger.logError("Custom OpenAI test - failed to serialize request body")
            return .failure(message: "Failed to create request")
        }
        request.httpBody = bodyData

        do {
            let (data, httpResponse) = try await networkService.send(request, acceptableStatusCodes: Set<Int>.acceptAny)

            let responseString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
            logger.logNotice("Custom OpenAI test - status \(httpResponse.statusCode), response prefix: \(responseString.prefix(500))")

            switch httpResponse.statusCode {
            case 200:
                return .success(message: "Connected successfully")
            case 401:
                return .failure(message: "Authentication failed. Check your API key.")
            case 404:
                return .failure(message: "Endpoint not found. Check the URL.")
            case 400:
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    return .failure(message: message)
                }
                return .failure(message: "Bad request: \(responseString.prefix(200))")
            case 500...599:
                return .failure(message: "Server error (\(httpResponse.statusCode)). Try again later.")
            default:
                return .failure(message: "HTTP \(httpResponse.statusCode): \(responseString.prefix(200))")
            }
        } catch {
            // Unwrap to surface a friendly message for transport errors.
            // `as?` is used inside a single catch block because typed catch
            // patterns (e.g. `catch let e as NetworkError`) were observed
            // to not match a Networking.NetworkError thrown across an async
            // boundary in this code path - cause unclear.
            if let urlError = unwrapURLError(error) {
                logger.logError("Custom OpenAI test - URLError \(urlError.code.rawValue): \(urlError.localizedDescription)")
                return .failure(message: mapURLError(urlError))
            }
            logger.logError("Custom OpenAI test - error: \(error)")
            return .failure(message: "Error: \(error.localizedDescription)")
        }
    }

    /// Extracts the underlying `URLError` from either a raw URLError throw or
    /// a `NetworkError.transport(URLError)` wrap. Returns `nil` for
    /// non-URL-error throws.
    ///
    /// ## Two paths, two contexts
    ///
    /// - **In production**, the typed `error as? NetworkError` cast succeeds
    ///   and the helper returns via the second clause.
    /// - **In the test bundle**, the typed cast returns `nil` even when the
    ///   dynamic type is `NetworkError` - apparently because the `Networking`
    ///   module is loaded twice (once into the app, once via the test target's
    ///   explicit `import Networking` alongside `@testable import VivaDicta`),
    ///   producing two distinct `NetworkError` types with the same nominal
    ///   name. `as?` does strict identity comparison and fails. The
    ///   `String(describing:)` fallback parses the NSError-bridged form
    ///   (`transport(Error Domain=NSURLErrorDomain Code=-1004 ...)`) to
    ///   recover the URL error code.
    ///
    /// If the dual-link is ever fixed (e.g., by making `Networking` a dynamic
    /// library or dropping the test target's explicit import), the fallback
    /// becomes unreachable - but it's cheap insurance.
    private func unwrapURLError(_ error: any Error) -> URLError? {
        if let urlError = error as? URLError {
            return urlError
        }
        if let networkError = error as? NetworkError,
           case let .transport(underlying) = networkError,
           let urlError = underlying as? URLError {
            return urlError
        }
        let description = String(describing: error)
        if description.hasPrefix("transport("),
           let codeMatch = description.range(of: #"Code=(-?\d+)"#, options: .regularExpression) {
            let codeString = String(description[codeMatch]).replacing("Code=", with: "")
            if let code = Int(codeString) {
                return URLError(URLError.Code(rawValue: code))
            }
        }
        return nil
    }

    private func mapURLError(_ error: URLError) -> String {
        switch error.code {
        case .cannotConnectToHost:
            return "Cannot connect to server. Check the URL and that the server is running."
        case .timedOut:
            return "Connection timed out. Server may be slow or unreachable."
        case .notConnectedToInternet:
            return "No internet connection."
        default:
            return "Connection error: \(error.localizedDescription)"
        }
    }
}
