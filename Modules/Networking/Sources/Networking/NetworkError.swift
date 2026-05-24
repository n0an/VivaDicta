// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

/// Structured error surface for ``NetworkClient``. Callers can switch on this
/// to translate into module-specific errors (e.g. `EnhancementError`,
/// `CloudTranscriptionError`) without losing the raw status code or body.
public enum NetworkError: Error, Sendable {
    /// The response was not an `HTTPURLResponse`. Almost always indicates a
    /// programming or test fixture problem rather than a real network event.
    case invalidResponse

    /// Server responded but the status code wasn't in the acceptable range.
    /// `body` carries the raw response payload for richer error messages.
    case unacceptableStatus(code: Int, body: Data)

    /// JSON decoding failed for a typed `sendJSON` call.
    case decodingFailed(any Error)

    /// Underlying URLSession failure (network down, timeout, etc.).
    case transport(any Error)

    /// HTTP status code, if known. Useful for callers that need to special-case
    /// `429`, `401` etc. without unwrapping the enum.
    public var statusCode: Int? {
        if case let .unacceptableStatus(code, _) = self { return code }
        return nil
    }

    /// Raw response body bytes for non-2xx responses, empty otherwise.
    public var bodyData: Data {
        if case let .unacceptableStatus(_, body) = self { return body }
        return Data()
    }

    /// UTF-8 decoded body, or an empty string if the body wasn't valid UTF-8.
    public var bodyString: String {
        String(data: bodyData, encoding: .utf8) ?? ""
    }
}
