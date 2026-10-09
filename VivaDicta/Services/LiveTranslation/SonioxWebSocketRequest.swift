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
/// 2027-01-15 (401 after that). Both schemes at once get a 400 error frame, so
/// the clients must leave `api_key` out of their payloads entirely.
/// https://soniox.com/docs/guides/websocket-authentication
enum SonioxWebSocketRequest {
    static func make(endpoint: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
}
