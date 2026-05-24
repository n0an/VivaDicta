// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import TestUtilities

/// Hand-rolled mock of ``NetworkService`` for consumer tests. Stubs per-method
/// responses, captures requests and bodies, counts calls. Each test creates
/// its own instance - no global state - so suites run in parallel safely.
///
/// ## Usage
///
/// ```swift
/// let net = MockNetworkService()
/// net.stubSendResponse = .success((Data(#"{"text":"hello"}"#.utf8), httpResponse(200)))
/// let service = OpenAIChatService(networkService: net)
/// _ = try await service.chat(...)
/// #expect(net.sendCallCount == 1)
/// #expect(net.capturedRequest?.url?.path == "/v1/chat/completions")
/// ```
///
/// ## `bytes(for:)` limitation
///
/// `URLSession.AsyncBytes` has no public initializer, so `bytes(for:)` cannot
/// be stubbed to return a synthetic stream. Tests of SSE / streaming paths
/// should be integration tests or rely on a real `URLSession` against a
/// controlled local server. Calling `bytes(for:)` on this mock throws
/// `StubNotSetError`.
public final class MockNetworkService: NetworkService, @unchecked Sendable {
    public init() {}

    // MARK: - send

    public var stubSendResponse: Result<(Data, HTTPURLResponse), Error>?
    public var didSend: (() -> Void)?
    public private(set) var sendCallCount = 0

    // MARK: - sendJSON

    /// Per-test stub for `sendJSON`. Stored as `Any` because the return type
    /// is generic; tests put a `T` value here (or wrap an Error). The mock
    /// type-checks at call time and throws `StubNotSetError` if the stub
    /// doesn't match the requested `T`.
    public var stubSendJSONResponse: Result<Any, Error>?
    public var didSendJSON: (() -> Void)?
    public private(set) var sendJSONCallCount = 0

    // MARK: - upload

    public var stubUploadResponse: Result<(Data, HTTPURLResponse), Error>?
    public var didUpload: (() -> Void)?
    public private(set) var uploadCallCount = 0
    public private(set) var capturedBody: Data?

    // MARK: - bytes

    public private(set) var bytesCallCount = 0

    // MARK: - shared capture

    /// Most recent request seen by any method. For suites exercising multiple
    /// endpoints, snapshot inline after each call rather than relying on the
    /// final value.
    public private(set) var capturedRequest: URLRequest?

    /// All requests seen, in order. Useful for asserting a sequence.
    public private(set) var capturedRequests: [URLRequest] = []

    /// Most recent `acceptableStatusCodes` override passed in (nil = used the
    /// default 200..<300).
    public private(set) var capturedAcceptableStatusCodes: Set<Int>?

    // MARK: - NetworkService conformance

    public func send(
        _ request: URLRequest,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (Data, HTTPURLResponse) {
        defer { didSend?() }
        sendCallCount += 1
        capturedRequest = request
        capturedRequests.append(request)
        capturedAcceptableStatusCodes = acceptableStatusCodes
        let (data, response): (Data, HTTPURLResponse) = try stubSendResponse.evaluate()
        try validateStatus(response, body: data, acceptable: acceptableStatusCodes)
        return (data, response)
    }

    public func sendJSON<T: Decodable>(
        _ request: URLRequest,
        as type: T.Type,
        decoder: JSONDecoder,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> T {
        defer { didSendJSON?() }
        sendJSONCallCount += 1
        capturedRequest = request
        capturedRequests.append(request)
        capturedAcceptableStatusCodes = acceptableStatusCodes
        let raw = try stubSendJSONResponse.evaluate() as Any
        guard let typed = raw as? T else {
            throw StubNotSetError("MockNetworkService.stubSendJSONResponse value \(raw) is not \(T.self)")
        }
        return typed
    }

    public func upload(
        _ request: URLRequest,
        from bodyData: Data,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (Data, HTTPURLResponse) {
        defer { didUpload?() }
        uploadCallCount += 1
        capturedRequest = request
        capturedRequests.append(request)
        capturedAcceptableStatusCodes = acceptableStatusCodes
        capturedBody = bodyData
        let (data, response): (Data, HTTPURLResponse) = try stubUploadResponse.evaluate()
        try validateStatus(response, body: data, acceptable: acceptableStatusCodes)
        return (data, response)
    }

    // MARK: - Helpers

    /// Mirrors `DefaultNetworkService`'s status validation so consumer tests
    /// that stub a non-2xx HTTPURLResponse get the same `NetworkError`
    /// production code would see. Otherwise the mock would silently bypass
    /// the validation that `DefaultNetworkService` runs.
    private func validateStatus(
        _ response: HTTPURLResponse,
        body: Data,
        acceptable: Set<Int>?
    ) throws {
        let acceptableCodes = acceptable ?? Set(200..<300)
        if !acceptableCodes.contains(response.statusCode) {
            throw NetworkError.unacceptableStatus(code: response.statusCode, body: body)
        }
    }

    public func bytes(
        for request: URLRequest,
        acceptableStatusCodes: Set<Int>?
    ) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        bytesCallCount += 1
        capturedRequest = request
        capturedRequests.append(request)
        capturedAcceptableStatusCodes = acceptableStatusCodes
        throw StubNotSetError(
            "MockNetworkService.bytes(for:) cannot be stubbed: URLSession.AsyncBytes has no public initializer. Test SSE / streaming paths via integration."
        )
    }
}
