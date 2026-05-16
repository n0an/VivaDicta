// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// `URLProtocol` subclass that intercepts every request flowing through a
/// `URLSession` configured to use it, returning a canned response built by the
/// `requestHandler` closure. Used by cloud-service tests to exercise network
/// code without hitting the real network.
///
/// ## Usage
///
/// ```swift
/// MockURLProtocol.requestHandler = { request in
///     let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
///     return (response, Data(#"{"text": "hello"}"#.utf8))
/// }
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
/// // ... use session ...
/// MockURLProtocol.reset()
/// ```
///
/// ## State
///
/// Mock state is per-process global because `URLProtocol` subclasses are
/// registered as types, not instances. Each test should call
/// `MockURLProtocol.reset()` to clear handler + capture state before/after.
/// Tests using this protocol should not run in parallel against each other
/// (Swift Testing runs `@Suite` tests serially by default within a struct
/// initializer, so suite-scoped state is safe).
final class MockURLProtocol: URLProtocol {

    /// Returns the (response, body) pair to deliver for the intercepted
    /// request. Set before invoking the service under test.
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    /// The most recent intercepted request. Set in `startLoading`.
    nonisolated(unsafe) static var capturedRequest: URLRequest?

    /// The body data of the most recent intercepted request, read from the
    /// upload's HTTP body stream (which is how `URLSession.upload(for:from:)`
    /// transports the body).
    nonisolated(unsafe) static var capturedBody: Data?

    /// Clears all static state. Call at the start of each test.
    static func reset() {
        requestHandler = nil
        capturedRequest = nil
        capturedBody = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedRequest = request
        Self.capturedBody = Self.readUploadBody(from: request)

        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    /// Reads the upload body from either `httpBody` or `httpBodyStream`.
    /// `URLSession.upload(for:from:)` wraps the `Data` payload in an
    /// `InputStream`, so we drain it here.
    private static func readUploadBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

/// Builds a URLSession that routes every request through `MockURLProtocol`.
/// Use one per test.
func makeMockedURLSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}
