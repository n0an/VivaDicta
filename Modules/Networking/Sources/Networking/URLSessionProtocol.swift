// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Abstraction over `URLSession` used so services can be tested without
/// hitting the real network. Production code receives `URLSession.shared`
/// via the conformance extension below; tests inject a `MockURLSession`
/// from `NetworkingMocks`.
///
/// Methods mirror the small set of `URLSession` async APIs we actually use:
///
/// - ``data(for:)`` for plain request/response calls.
/// - ``upload(for:from:)`` for multipart / large body POSTs.
/// - ``bytes(for:)`` for streaming Server-Sent Events endpoints. The return
///   type is `URLSession.AsyncBytes` because there is no constructible
///   replacement; SSE-flavored code paths typically rely on integration
///   tests rather than `MockURLSession` stubbing.
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse)
}

extension URLSession: URLSessionProtocol {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await self.data(for: request, delegate: nil)
    }

    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        try await self.upload(for: request, from: bodyData, delegate: nil)
    }

    public func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        try await self.bytes(for: request, delegate: nil)
    }
}
