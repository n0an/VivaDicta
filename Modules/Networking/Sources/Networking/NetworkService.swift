// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Consumer-facing seam for all HTTP traffic. Domain services
/// (`AIService`, the cloud transcription services, OAuth managers, etc.)
/// inject `NetworkService` and never touch `URLSession`/`URLSessionProtocol`
/// directly.
///
/// Tests inject a `MockNetworkService` from `NetworkingMocks`. `URLSession`
/// and `MockURLSession` are intentionally scoped as implementation details of
/// the production conformance ``DefaultNetworkService`` -- if consumer tests
/// need to fake HTTP, they fake `NetworkService`, not `URLSession`.
///
/// Methods mirror the small set of HTTP patterns this codebase actually uses:
///
/// - ``send(_:acceptableStatusCodes:)`` for plain request/response calls with
///   status validation.
/// - ``sendJSON(_:as:decoder:acceptableStatusCodes:)`` for the very common
///   "send a request, decode the body as `T`" pattern.
/// - ``upload(_:from:acceptableStatusCodes:)`` for multipart / large body
///   POSTs.
/// - ``bytes(for:acceptableStatusCodes:)`` for Server-Sent Events / streaming
///   endpoints.
public protocol NetworkService: Sendable {
    func send(
        _ request: URLRequest,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (Data, HTTPURLResponse)

    func sendJSON<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        decoder: JSONDecoder,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> T

    func upload(
        _ request: URLRequest,
        from bodyData: Data,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (Data, HTTPURLResponse)

    func bytes(
        for request: URLRequest,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse)
}

// MARK: - Ergonomic defaults

/// Convenience overloads with sensible defaults so call sites stay clean.
public extension NetworkService {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await send(request, acceptableStatusCodes: nil)
    }

    func sendJSON<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        try await sendJSON(request, as: type, decoder: decoder, acceptableStatusCodes: nil)
    }

    func upload(_ request: URLRequest, from bodyData: Data) async throws -> (Data, HTTPURLResponse) {
        try await upload(request, from: bodyData, acceptableStatusCodes: nil)
    }

    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        try await bytes(for: request, acceptableStatusCodes: nil)
    }
}
