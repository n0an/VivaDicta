// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking

/// A `URLProtocol` stub that lets tests drive a *real* `URLSession` - and thus
/// a genuine `URLSession.AsyncBytes` stream - entirely offline. This is the
/// only way to exercise the SSE / streaming code paths
/// (`GeminiAPIClient.chatStreaming`, `enhanceStreaming`, etc.): `AsyncBytes`
/// has no public initializer, so `MockNetworkService.bytes(for:)` cannot
/// fabricate one. Instead we register this protocol on an ephemeral session
/// configuration, hand that real session to `DefaultNetworkService`, and replay
/// a canned HTTP status + body when the request fires.
///
/// Because the stub is shared static state, streaming suites that use it must
/// be `.serialized`.
final class StreamingURLProtocol: URLProtocol {

    struct Stub {
        var statusCode: Int
        var body: Data
        var headers: [String: String] = ["Content-Type": "text/event-stream"]
    }

    nonisolated(unsafe) static var stub: Stub?

    /// A `DefaultNetworkService` wired to a fresh session that routes every
    /// request through this protocol. Set ``stub`` before issuing the request.
    static func makeNetworkService() -> DefaultNetworkService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StreamingURLProtocol.self]
        return DefaultNetworkService(session: URLSession(configuration: configuration), category: "StreamingTest")
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let stub = StreamingURLProtocol.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
