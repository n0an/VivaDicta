// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import Testing
@testable import VivaDicta

/// Guards the realtime-to-async mapping for the two models that exist only on a
/// socket: Cartesia's Ink 2 and Gemini's Live transcribe.
///
/// Both are rejected outright by their provider's upload endpoint - Cartesia's
/// batch `/stt` takes the `ink-whisper` family and nothing else, and
/// `gemini-3.5-transcribe-live` is served by the Live socket rather than the
/// Interactions API. Two paths still reach the upload endpoint while one of them
/// is selected: keyboard dictation, and the fallback after a dropped socket.
/// Without the remap, the fallback the streaming design depends on would fail
/// with the very error it exists to recover from.
@MainActor
struct RealtimeOnlyModelRoutingTests {

    @Test(arguments: [
        TranscriptionModelProvider.cartesiaRealtimeModel,
        TranscriptionModelProvider.geminiLiveRealtimeModel
    ])
    func realtimeOnlyModelsAreRecognisedAsStreaming(name: String) {
        #expect(TranscriptionModelProvider.isStreamingModel(name))
    }

    @Test(arguments: [
        TranscriptionModelProvider.cartesiaBatchModel,
        TranscriptionModelProvider.geminiBatchTranscribeModel
    ])
    func batchCounterpartsAreNotStreaming(name: String) {
        #expect(TranscriptionModelProvider.isStreamingModel(name) == false)
    }

    @Test func inkTwoMapsToInkWhisperForUploadPath() {
        let mapped = TranscriptionModelProvider.asyncEquivalent(
            of: TranscriptionModelProvider.cartesiaRealtimeModel
        )

        #expect(mapped == TranscriptionModelProvider.cartesiaBatchModel)
        #expect(mapped != TranscriptionModelProvider.cartesiaRealtimeModel)
    }

    @Test func geminiLiveMapsToTranscribeForUploadPath() {
        let mapped = TranscriptionModelProvider.asyncEquivalent(
            of: TranscriptionModelProvider.geminiLiveRealtimeModel
        )

        #expect(mapped == TranscriptionModelProvider.geminiBatchTranscribeModel)
        #expect(mapped != TranscriptionModelProvider.geminiLiveRealtimeModel)
    }

    /// Each realtime entry has to exist in the catalog for the picker to offer
    /// it, and sit under the right provider for key lookup to work.
    @Test(arguments: [
        (TranscriptionModelProvider.cartesiaRealtimeModel, TranscriptionModelProvider.cartesia),
        (TranscriptionModelProvider.geminiLiveRealtimeModel, TranscriptionModelProvider.gemini)
    ])
    func catalogExposesRealtimeModelUnderItsProvider(
        name: String,
        provider: TranscriptionModelProvider
    ) throws {
        let model = try #require(
            TranscriptionModelProvider.allCloudModels.first { $0.name == name }
        )

        #expect(model.provider == provider)
    }

    /// Cartesia caps keyterms at 100 terms and 1,200 characters combined, and
    /// rejects the handshake when either is exceeded - which would take the
    /// whole socket down rather than just dropping the extra vocabulary.
    @Test func keytermsStayWithinCartesiaHandshakeLimits() {
        let terms = (0..<400).map { "term\($0)" }

        let sut = CartesiaRealtimeSession.keyterms(from: terms)

        #expect(sut.count <= 100)
        #expect(sut.reduce(0) { $0 + $1.count } <= 1_200)
        #expect(sut.first == "term0")
    }

    @Test func keytermsDropEmptyEntriesAndPassSmallListsThrough() {
        let sut = CartesiaRealtimeSession.keyterms(from: ["Kubernetes", "", "Novoselov"])

        #expect(sut == ["Kubernetes", "Novoselov"])
    }

    /// A single very long term must not consume the whole character budget and
    /// starve the rest - it is skipped, and shorter terms after it still fit.
    @Test func keytermsSkipATermThatWouldBlowTheCharacterBudget() {
        let oversized = String(repeating: "x", count: 1_300)

        let sut = CartesiaRealtimeSession.keyterms(from: [oversized, "Swift"])

        #expect(sut == ["Swift"])
    }
}
