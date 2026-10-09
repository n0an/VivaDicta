//
//  SonioxWebSocketRequest.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.10.09
//

import Foundation

/// Builds the upgrade request for Soniox realtime sockets (STT and TTS).
///
/// Soniox authenticates the *connection*, not the first message: the key goes
/// in the `Authorization` header of the WebSocket handshake. Putting `api_key`
/// in the start/config payload is the legacy scheme and stops working on
/// 2027-01-15 (401 after that). The start/config message should omit `api_key`;
/// a different key there is rejected with a 400 error frame. A bad key
/// still does not fail the handshake: Soniox opens the socket and sends an
/// `error_message` frame, which the clients already surface as `.failed`.
/// https://soniox.com/docs/guides/websocket-authentication
///
/// `nonisolated` because the target defaults to MainActor isolation and both
/// callers are plain actors that build the request synchronously.
nonisolated enum SonioxWebSocketRequest {
    static func make(endpoint: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        // Settings only checked that the trimmed key is non-empty; a pasted
        // trailing newline used to be JSON-escaped harmlessly, in a header it
        // would be malformed. Trim here so both clients get it for free.
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return request
    }
}
