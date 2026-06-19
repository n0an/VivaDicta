// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// A `URLProtocol` that intercepts requests issued through a real `URLSession`
/// and returns a canned response / body / error - the "don't mock a type you do
/// not own; intercept it" technique. Register it on an ephemeral
/// `URLSessionConfiguration` (see ``makeSession()``) so a real `URLSession`
/// exercises the actual loading path without touching the network.
///
/// The stub is process-global, so drive it from a `.serialized` suite and
/// `reset()` after each test.
final class URLProtocolStub: URLProtocol {
    struct Stub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    nonisolated(unsafe) static var stub: Stub?

    static func stub(data: Data?, response: URLResponse?, error: Error? = nil) {
        stub = Stub(data: data, response: response, error: error)
    }

    static func reset() {
        stub = nil
    }

    /// A real `URLSession` wired to this stub via an ephemeral configuration.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Response first so `URLSession.bytes(for:)` can return its headers,
        // then the body bytes the AsyncBytes stream yields, then completion.
        if let response = Self.stub?.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data = Self.stub?.data {
            client?.urlProtocol(self, didLoad: data)
        }
        if let error = Self.stub?.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
