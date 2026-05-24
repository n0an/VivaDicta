// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import os

/// Thin wrapper around `URLSessionProtocol` that centralizes the boilerplate
/// each HTTP-talking client used to repeat: status code validation, JSON
/// decoding, logging of non-2xx bodies, and translation of underlying URL
/// errors into a structured ``NetworkError``.
///
/// Designed to be cheap to construct and `Sendable`: hold one in a service or
/// create per-request. Production callers default to `URLSession.shared`;
/// tests inject a `MockURLSession`.
///
/// ## Typical usage
///
/// ```swift
/// struct GeminiClient {
///     private let client = NetworkClient(category: "Gemini")
///
///     func fetchModels() async throws -> [Model] {
///         var request = URLRequest(url: modelsURL)
///         request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
///         return try await client.sendJSON(request, as: ModelsResponse.self).models
///     }
/// }
/// ```
public struct NetworkClient: Sendable {
    private let session: any URLSessionProtocol
    private let logger: Logger
    private let acceptableStatusCodes: Set<Int>

    /// - Parameters:
    ///   - session: Injected URLSession. Defaults to `URLSession.shared` for
    ///     production callers; tests pass a `MockURLSession`.
    ///   - category: Subsystem-specific log category (e.g. `"OpenAIChat"`).
    ///     Errors and non-2xx responses are logged under this category.
    ///   - acceptableStatusCodes: Status codes treated as success. Defaults
    ///     to `200..<300`. Anything else surfaces as
    ///     `NetworkError.unacceptableStatus`.
    public init(
        session: any URLSessionProtocol = URLSession.shared,
        category: String = "NetworkClient",
        acceptableStatusCodes: Set<Int> = Set(200..<300)
    ) {
        self.session = session
        self.logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.networking", category: category)
        self.acceptableStatusCodes = acceptableStatusCodes
    }

    // MARK: - Plain request/response

    /// Send the request, validate the response, and return the raw body bytes
    /// alongside the `HTTPURLResponse`.
    public func send(
        _ request: URLRequest,
        acceptableStatusCodes: Set<Int>? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await callData(request)
        let http = try validate(response: response, body: data, acceptable: acceptableStatusCodes)
        return (data, http)
    }

    /// Send the request and decode the response body as `T`.
    public func sendJSON<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder(),
        acceptableStatusCodes: Set<Int>? = nil
    ) async throws -> T {
        let (data, _) = try await send(request, acceptableStatusCodes: acceptableStatusCodes)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("JSON decode failed for \(request.url?.absoluteString ?? "<no url>", privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Upload (multipart / large body)

    /// Send the request body via `URLSession.upload(for:from:)`. Validates the
    /// response status and returns the body + HTTP response.
    public func upload(
        _ request: URLRequest,
        from bodyData: Data,
        acceptableStatusCodes: Set<Int>? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.upload(for: request, from: bodyData)
        } catch {
            throw NetworkError.transport(error)
        }
        let http = try validate(response: response, body: data, acceptable: acceptableStatusCodes)
        return (data, http)
    }

    // MARK: - Streaming (SSE)

    /// Open a byte stream for server-sent-events style endpoints. Validates
    /// the status code first (draining the body on failure into
    /// `NetworkError.unacceptableStatus`) and returns the stream + response
    /// for the caller to iterate.
    public func bytes(
        for request: URLRequest,
        acceptableStatusCodes: Set<Int>? = nil
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw NetworkError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        let acceptable = acceptableStatusCodes ?? self.acceptableStatusCodes
        if !acceptable.contains(http.statusCode) {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let body = String(data: errorData, encoding: .utf8) ?? ""
            logger.error("HTTP \(http.statusCode, privacy: .public) from \(request.url?.absoluteString ?? "<no url>", privacy: .public): \(body, privacy: .public)")
            throw NetworkError.unacceptableStatus(code: http.statusCode, body: errorData)
        }
        return (bytes, http)
    }

    // MARK: - Private helpers

    private func callData(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error)
        }
    }

    private func validate(
        response: URLResponse,
        body: Data,
        acceptable overrideAcceptable: Set<Int>?
    ) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        let acceptable = overrideAcceptable ?? self.acceptableStatusCodes
        if !acceptable.contains(http.statusCode) {
            let bodyText = String(data: body, encoding: .utf8) ?? ""
            logger.error("HTTP \(http.statusCode, privacy: .public) from \(http.url?.absoluteString ?? "<no url>", privacy: .public): \(bodyText, privacy: .public)")
            throw NetworkError.unacceptableStatus(code: http.statusCode, body: body)
        }
        return http
    }
}
