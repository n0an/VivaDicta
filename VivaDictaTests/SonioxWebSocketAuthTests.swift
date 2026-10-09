// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// Pins the Soniox realtime auth scheme.
///
/// Soniox retires `api_key` in the first WebSocket message on 2027-01-15; from
/// then on the key must be sent with the connection. The start/config message
/// should omit it (a different key there is rejected). These tests fail
/// if either client drifts back to the legacy payload field, or if the header
/// goes missing from the upgrade request.
/// https://soniox.com/docs/guides/websocket-authentication
struct SonioxWebSocketAuthTests {
    @Test func upgradeRequestCarriesBearerHeader() {
        let endpoint = URL(string: "wss://example.soniox.com/socket")!
        let request = SonioxWebSocketRequest.make(endpoint: endpoint, apiKey: "snx_temp_abc")

        #expect(request.url == endpoint)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer snx_temp_abc")
    }

    /// Settings only reject a key whose *trimmed* form is empty, so a pasted
    /// trailing newline reaches the client. Inside a header it must not survive.
    @Test func upgradeRequestTrimsWhitespaceAroundKey() {
        let endpoint = URL(string: "wss://example.soniox.com/socket")!
        let request = SonioxWebSocketRequest.make(endpoint: endpoint, apiKey: " snx_temp_abc\n")

        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer snx_temp_abc")
    }

    @Test func sttUpgradeRequestTargetsSttEndpointWithBearer() {
        let request = SonioxRealtimeSTTClient.makeUpgradeRequest(apiKey: "k1")

        #expect(request.url == SonioxRealtimeSTTClient.endpoint)
        #expect(request.url?.absoluteString == "wss://stt-rt.soniox.com/transcribe-websocket")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer k1")
    }

    @Test func ttsUpgradeRequestTargetsTtsEndpointWithBearer() {
        let request = SonioxRealtimeTTSClient.makeUpgradeRequest(apiKey: "k2")

        #expect(request.url == SonioxRealtimeTTSClient.endpoint)
        #expect(request.url?.absoluteString == "wss://tts-rt.soniox.com/tts-websocket")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer k2")
    }

    @Test(arguments: [
        SonioxRealtimeSTTClient.Mode.transcription,
        SonioxRealtimeSTTClient.Mode.translation(target: .spanish)
    ])
    func sttStartMessageHasNoAPIKey(mode: SonioxRealtimeSTTClient.Mode) {
        let payload = SonioxRealtimeSTTClient.makeConfigPayload(
            languageHints: ["en"],
            mode: mode,
            vocabularyTerms: ["VivaDicta"]
        )

        #expect(payload["api_key"] == nil)
        #expect(payload["model"] as? String == SonioxRealtimeSTTClient.model)
        #expect(payload["audio_format"] as? String == "pcm_s16le")
        #expect(payload["sample_rate"] as? Int == 16000)
        #expect(payload["language_hints"] as? [String] == ["en"])
        #expect((payload["context"] as? [String: Any])?["terms"] as? [String] == ["VivaDicta"])

        let translation = payload["translation"] as? [String: Any]
        if case .translation = mode {
            #expect(translation?["type"] as? String == "one_way")
            #expect(translation?["target_language"] as? String == "es")
        } else {
            #expect(translation == nil)
        }
    }

    @Test func ttsConfigMessageHasNoAPIKey() {
        let payload = SonioxRealtimeTTSClient.makeConfigPayload(
            language: .english,
            voice: "test-voice",
            streamID: "vivadicta-test"
        )

        #expect(payload["api_key"] == nil)
        #expect(payload["model"] as? String == "tts-rt-v1-preview")
        #expect(payload["language"] as? String == "en")
        #expect(payload["voice"] as? String == "test-voice")
        #expect(payload["audio_format"] as? String == "pcm_s16le")
        #expect(payload["sample_rate"] as? Int == Int(SonioxRealtimeTTSClient.outputSampleRate))
        #expect(payload["stream_id"] as? String == "vivadicta-test")
    }
}
