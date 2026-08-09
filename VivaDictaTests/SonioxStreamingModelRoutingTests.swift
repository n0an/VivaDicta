// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// Guards the realtime-to-async model mapping.
///
/// Soniox's realtime slug (`stt-rt-v5`) is rejected by the async
/// `/v1/transcriptions` endpoint, but two paths deliberately reach that
/// endpoint while the realtime model is selected: keyboard dictation, and the
/// fallback after a dropped socket. Without the remap the fallback the whole
/// streaming design depends on would fail with the very error it exists to
/// recover from - so this stays pinned.
@MainActor
struct SonioxStreamingModelRoutingTests {

    @Test func realtimeModelIsRecognisedAsStreaming() {
        #expect(TranscriptionModelProvider.isStreamingModel(TranscriptionModelProvider.sonioxRealtimeModel))
    }

    @Test func asyncModelIsNotStreaming() {
        #expect(TranscriptionModelProvider.isStreamingModel(TranscriptionModelProvider.sonioxAsyncModel) == false)
    }

    @Test func realtimeModelMapsToAsyncForUploadPath() {
        let mapped = TranscriptionModelProvider.asyncEquivalent(of: TranscriptionModelProvider.sonioxRealtimeModel)

        #expect(mapped == TranscriptionModelProvider.sonioxAsyncModel)
        #expect(mapped != TranscriptionModelProvider.sonioxRealtimeModel)
    }

    @Test func asyncModelPassesThroughUnchanged() {
        let name = TranscriptionModelProvider.sonioxAsyncModel

        #expect(TranscriptionModelProvider.asyncEquivalent(of: name) == name)
    }

    @Test(arguments: ["whisper-1", "nova-3", "scribe_v1", "solaria-1", ""])
    func otherProviderModelsPassThroughUnchanged(name: String) {
        #expect(TranscriptionModelProvider.asyncEquivalent(of: name) == name)
    }

    /// The realtime entry has to exist in the catalog for the picker to offer
    /// it, and it has to sit under the Soniox provider for key lookup to work.
    @Test func catalogExposesRealtimeModelUnderSoniox() {
        let realtime = TranscriptionModelProvider.allCloudModels.first {
            $0.name == TranscriptionModelProvider.sonioxRealtimeModel
        }

        let model = try? #require(realtime)
        #expect(model?.provider == .soniox)
    }
}
