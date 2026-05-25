// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
@testable import CloudTranscription
import Networking
import Testing

@Suite("NetworkError → transcription error bridge", .tags(.networking))
struct NetworkErrorBridgeTests {

    @Test func unacceptableStatusMapsToApiRequestFailed() {
        let bridged = NetworkError.unacceptableStatus(code: 429, body: Data("rate limited".utf8))
            .asTranscriptionError()

        guard case let CloudTranscriptionError.apiRequestFailed(code, message) = bridged else {
            Issue.record("Expected .apiRequestFailed, got \(bridged)")
            return
        }
        #expect(code == 429)
        #expect(message == "rate limited")
    }

    @Test func invalidResponseMapsToNetworkError() {
        let bridged = NetworkError.invalidResponse.asTranscriptionError()

        guard case CloudTranscriptionError.networkError = bridged else {
            Issue.record("Expected .networkError, got \(bridged)")
            return
        }
    }

    @Test func decodingFailureMapsToNoTranscriptionReturned() {
        struct Boom: Error {}
        let bridged = NetworkError.decodingFailed(Boom()).asTranscriptionError()

        guard case CloudTranscriptionError.noTranscriptionReturned = bridged else {
            Issue.record("Expected .noTranscriptionReturned, got \(bridged)")
            return
        }
    }

    /// Regression test for the retry-on-cancel bug both reviewers flagged on
    /// PR #278: `.transport` previously bridged to
    /// `CloudTranscriptionError.networkError`, which `NetworkRetry` retries
    /// unconditionally. The bridge now unwraps the underlying URLError so
    /// `NetworkRetry.shouldRetryURLError` keeps gating on its allowlist.
    @Test func transportUnwrapsToUnderlyingURLError() {
        let original = URLError(.cancelled)
        let bridged = NetworkError.transport(original).asTranscriptionError()

        let urlError = bridged as? URLError
        #expect(urlError?.code == .cancelled)
        // Should NOT be wrapped as CloudTranscriptionError - that would force
        // an unconditional retry path in NetworkRetry.
        if case CloudTranscriptionError.networkError = bridged {
            Issue.record(".transport must not bridge to .networkError - that re-introduces the retry-on-cancel regression")
        }
    }
}
