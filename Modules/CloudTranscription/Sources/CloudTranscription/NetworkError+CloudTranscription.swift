// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking

/// Bridges `NetworkError` (produced by `NetworkClient`) into the error type
/// `NetworkRetry.withRetry` already knows how to inspect for retry decisions.
///
/// - `.invalidResponse` / `.unacceptableStatus` / `.decodingFailed` map to
///   `CloudTranscriptionError` so the status-aware retry policy (5xx + 429)
///   applies.
/// - `.transport(URLError)` is **unwrapped** to the raw underlying error so
///   `NetworkRetry.shouldRetryURLError`'s allowlist (`notConnected` /
///   `timedOut` / `connectionLost` / `cannotConnectToHost`) makes the call.
///   Wrapping these as `.networkError` would cause unconditional retry of
///   non-retryable codes like `URLError.cancelled` -- a UX regression on
///   user-initiated cancellation.
extension NetworkError {
    func asTranscriptionError() -> any Error {
        switch self {
        case .invalidResponse:
            return CloudTranscriptionError.networkError(URLError(.badServerResponse))
        case let .unacceptableStatus(code, body):
            let message = String(data: body, encoding: .utf8) ?? "No error message"
            return CloudTranscriptionError.apiRequestFailed(statusCode: code, message: message)
        case let .transport(error):
            return error
        case .decodingFailed:
            return CloudTranscriptionError.noTranscriptionReturned
        }
    }
}
