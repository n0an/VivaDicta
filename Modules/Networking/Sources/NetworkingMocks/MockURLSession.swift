// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking
import TestUtilities

/// Hand-rolled mock that conforms to `URLSessionProtocol`. Each test creates
/// its own instance and stubs the response - no global state, so suites can
/// run in parallel safely.
///
/// ## Usage
///
/// ```swift
/// let session = MockURLSession()
/// session.stubDataResponse = .success((Data(#"{"text":"hello"}"#.utf8), httpResponse(200)))
/// let service = SomeService(urlSession: session)
/// _ = try await service.fetch()
/// #expect(session.dataCallCount == 1)
/// #expect(session.capturedRequest?.httpMethod == "POST")
/// ```
///
/// `bytes(for:)` is intentionally unstubbable: there is no public initializer
/// for `URLSession.AsyncBytes`, so SSE / streaming code paths should be tested
/// via integration rather than `MockURLSession`. Calling `bytes(for:)` on the
/// mock triggers a `StubNotSetError` issue.
public final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    public init() {}

    // MARK: data(for:)

    public var stubDataResponse: Result<(Data, URLResponse), Error>?
    public var didFetchData: (() -> Void)?
    public private(set) var dataCallCount = 0

    // MARK: upload(for:from:)

    public var stubUploadResponse: Result<(Data, URLResponse), Error>?
    public var didUpload: (() -> Void)?
    public private(set) var uploadCallCount = 0
    public private(set) var capturedBody: Data?

    // MARK: bytes(for:)

    public var stubBytesError: Error?
    public private(set) var bytesCallCount = 0

    // MARK: shared

    /// Most recent request seen by any of `data`, `upload`, or `bytes`. For
    /// suites that exercise multiple endpoints, snapshot it inline after each
    /// call instead of relying on this property at the end.
    public private(set) var capturedRequest: URLRequest?

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        defer { didFetchData?() }
        dataCallCount += 1
        capturedRequest = request
        return try stubDataResponse.evaluate()
    }

    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        defer { didUpload?() }
        uploadCallCount += 1
        capturedRequest = request
        capturedBody = bodyData
        return try stubUploadResponse.evaluate()
    }

    public func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        bytesCallCount += 1
        capturedRequest = request
        if let stubBytesError {
            throw stubBytesError
        }
        throw StubNotSetError("MockURLSession.bytes(for:) cannot be stubbed: URLSession.AsyncBytes has no public initializer. Test streaming paths via integration or a real URLSession.")
    }
}
