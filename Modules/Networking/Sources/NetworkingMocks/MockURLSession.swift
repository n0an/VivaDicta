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
/// session.stubUploadResponse = .success((Data(#"{"text":"hello"}"#.utf8), httpResponse(200)))
/// let service = OpenAITranscriptionService(config: ..., urlSession: session)
/// _ = try await service.transcribe(audioURL: audio)
/// #expect(session.uploadCallCount == 1)
/// #expect(session.capturedRequest?.httpMethod == "POST")
/// #expect(session.capturedBody == expectedBody)
/// ```
public final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    public init() {}

    public var stubUploadResponse: Result<(Data, URLResponse), Error>?
    public var didUpload: (() -> Void)?
    public private(set) var uploadCallCount = 0
    public private(set) var capturedRequest: URLRequest?
    public private(set) var capturedBody: Data?

    public func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse) {
        defer { didUpload?() }
        uploadCallCount += 1
        capturedRequest = request
        capturedBody = bodyData
        return try stubUploadResponse.evaluate()
    }
}
