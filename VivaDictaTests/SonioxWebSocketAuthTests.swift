// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// Pins the Soniox realtime auth scheme.
///
/// Soniox retires `api_key` in the first WebSocket message on 2027-01-15; from
/// then on only the `Authorization: Bearer` header on the handshake works, and
/// sending both at once is rejected with a 400 error frame. These tests fail
/// if either client drifts back to the legacy payload field, or if the header
/// goes missing from the upgrade request.
/// https://soniox.com/docs/guides/websocket-authentication
struct SonioxWebSocketAuthTests {
    @Test func upgradeRequestCarriesBearerHeader() {
        let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
        let request = SonioxWebSocketRequest.make(endpoint: endpoint, apiKey: "snx_temp_abc")

        #expect(request.url == endpoint)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer snx_temp_abc")
    }

    @Test func sttStartMessageHasNoAPIKey() {
        let payload = SonioxRealtimeSTTClient.makeConfigPayload(
            languageHints: ["en"],
            mode: .translation(target: .spanish),
            vocabularyTerms: ["VivaDicta"]
        )

        #expect(payload["api_key"] == nil)
        #expect(payload["model"] as? String == SonioxRealtimeSTTClient.model)
    }

    @Test func ttsConfigMessageHasNoAPIKey() {
        let payload = SonioxRealtimeTTSClient.makeConfigPayload(
            language: .english,
            voice: "test-voice",
            streamID: "vivadicta-test"
        )

        #expect(payload["api_key"] == nil)
        #expect(payload["stream_id"] as? String == "vivadicta-test")
    }
}
