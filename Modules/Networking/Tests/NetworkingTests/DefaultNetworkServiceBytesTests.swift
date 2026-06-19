// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import Networking

/// Tests the `bytes(for:)` streaming path of `DefaultNetworkService` against a
/// real `URLSession` driven by ``URLProtocolStub``.
///
/// This is the one seam `MockNetworkService` cannot reach: `URLSession.AsyncBytes`
/// has no public initializer, so the streaming success path and the non-2xx
/// "drain the body into an error" path can only be exercised by intercepting a
/// real session. Serialized because `URLProtocolStub` holds a process-global stub.
@Suite(.serialized)
struct DefaultNetworkServiceBytesTests {

    private func makeSUT() -> DefaultNetworkService {
        DefaultNetworkService(session: URLProtocolStub.makeSession(), category: "BytesTests")
    }

    private func httpResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/stream")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func streamRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://example.com/stream")!)
    }

    private func drain(_ bytes: URLSession.AsyncBytes) async throws -> Data {
        var received = Data()
        for try await byte in bytes {
            received.append(byte)
        }
        return received
    }

    @Test func successReturnsResponseAndStreamsBody() async throws {
        let body = Data("hello stream".utf8)
        URLProtocolStub.stub(data: body, response: httpResponse(200))
        defer { URLProtocolStub.reset() }
        let sut = makeSUT()

        let (bytes, http) = try await sut.bytes(for: streamRequest())

        #expect(http.statusCode == 200)
        let received = try await drain(bytes)
        #expect(received == body)
    }

    @Test func nonSuccessStatusDrainsBodyAndThrowsUnacceptableStatus() async throws {
        let errorBody = Data("stream error detail".utf8)
        URLProtocolStub.stub(data: errorBody, response: httpResponse(500))
        defer { URLProtocolStub.reset() }
        let sut = makeSUT()

        let error = try await #require(throws: NetworkError.self) {
            _ = try await sut.bytes(for: streamRequest())
        }
        guard case let .unacceptableStatus(code, body) = error else {
            Issue.record("expected NetworkError.unacceptableStatus, got \(error)")
            return
        }
        #expect(code == 500)
        #expect(String(data: body, encoding: .utf8) == "stream error detail")
    }

    @Test func acceptableStatusOverrideLetsNonDefaultStatusStream() async throws {
        // 404 is normally unacceptable; passing it in acceptableStatusCodes must
        // let the stream through instead of throwing.
        let body = Data("custom-accept".utf8)
        URLProtocolStub.stub(data: body, response: httpResponse(404))
        defer { URLProtocolStub.reset() }
        let sut = makeSUT()

        let (bytes, http) = try await sut.bytes(for: streamRequest(), acceptableStatusCodes: [404])

        #expect(http.statusCode == 404)
        let received = try await drain(bytes)
        #expect(received == body)
    }

    @Test func nonHTTPResponseThrowsInvalidResponse() async throws {
        // A non-HTTP URLResponse must surface as NetworkError.invalidResponse.
        let response = URLResponse(
            url: URL(string: "https://example.com/stream")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        URLProtocolStub.stub(data: Data(), response: response)
        defer { URLProtocolStub.reset() }
        let sut = makeSUT()

        let error = try await #require(throws: NetworkError.self) {
            _ = try await sut.bytes(for: streamRequest())
        }
        guard case .invalidResponse = error else {
            Issue.record("expected NetworkError.invalidResponse, got \(error)")
            return
        }
    }
}
