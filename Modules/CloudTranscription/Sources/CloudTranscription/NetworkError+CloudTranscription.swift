// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Networking

/// Bridges `NetworkError` (produced by `NetworkClient`) into the
/// `CloudTranscriptionError` contract that `NetworkRetry.withRetry` already
/// knows how to inspect for retry decisions (429 / 5xx / URLError).
///
/// Lets transcription services adopt `NetworkClient` without giving up the
/// existing retry semantics.
extension NetworkError {
    func asCloudTranscriptionError() -> CloudTranscriptionError {
        switch self {
        case .invalidResponse:
            return .networkError(URLError(.badServerResponse))
        case let .unacceptableStatus(code, body):
            let message = String(data: body, encoding: .utf8) ?? "No error message"
            return .apiRequestFailed(statusCode: code, message: message)
        case let .transport(error):
            return .networkError(error)
        case .decodingFailed:
            return .noTranscriptionReturned
        }
    }
}
