// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Abstraction over `URLSession` used so services can be tested without
/// hitting the real network. Production code receives `URLSession.shared`
/// via the conformance extension below; tests inject a `MockURLSession`
/// from `NetworkingMocks`.
///
/// Methods are added on demand - only declare what some caller actually
/// uses. Today only `upload(for:from:)` is needed for the cloud
/// transcription services' multipart uploads.
public protocol URLSessionProtocol: Sendable {
    func upload(for request: URLRequest, from bodyData: Data) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
