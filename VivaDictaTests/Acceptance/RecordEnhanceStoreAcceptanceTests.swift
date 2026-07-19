// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import SwiftData
import Testing
import AICore
import AIKit
import Keychain
import KeychainMocks
import Networking
import NetworkingMocks
import OAuth
import OAuthMocks
import Presets
import TranscriptionCore
@testable import VivaDicta

/// Acceptance tests for the core flow **record → transcribe → enhance → store**,
/// driven through the real headless orchestrator (`WatchAudioProcessor`) with
/// test doubles ONLY at the system boundary: a `MockTranscriber` (the transcribe
/// seam) and a mocked network/keychain. Everything in between is production code
/// - the real `AIService` (route resolution + registry + message building) and
/// the real SwiftData dual-write into an in-memory store.
///
/// This is the guardrail the modularization rides on: it pins the observable
/// outcome of the whole flow (a persisted `Transcription`, with or without its
/// enhanced `TranscriptionVariation`) so the pieces can move into modules without
/// silently breaking the composed behavior.
@Suite(.tags(.acceptance, .database, .networking))
@MainActor
struct RecordEnhanceStoreAcceptanceTests {

    // MARK: - Boundary doubles

    /// Stands in for `TranscriptionManager` at the `Transcriber` seam - returns
    /// deterministic text so the test owns the "transcribed" value (the real
    /// manager would need a downloaded/keyed model, which a test can't provide).
    private final class MockTranscriber: Transcriber {
        var currentMode: VivaMode
        let stubbedText: String
        init(currentMode: VivaMode, stubbedText: String) {
            self.currentMode = currentMode
            self.stubbedText = stubbedText
        }
        func setCurrentMode(_ mode: VivaMode) { currentMode = mode }
        func getCurrentTranscriptionModel() -> (any TranscriptionModel)? { nil }
        func transcribe(audioURL: URL, progressHandler: TranscriptionProgressHandler?) async throws -> TranscriptionServiceResult {
            .plain(stubbedText)
        }
    }

    /// CLI server is off, so the orchestration takes the cloud path.
    private final class StubCLIServerEnhancer: CLIServerEnhancer {
        var serverURL: String?
        func isCliActive(for provider: CLIServerProvider) -> Bool { false }
        func enhance(text: String, systemPrompt: String, model: String, provider: CLIServerProvider) async throws -> String { "" }
    }

    // MARK: - Helpers

    private func makeDefaults() -> UserDefaults {
        let suiteName = "RecordEnhanceStoreAcceptanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeMode(aiProvider: AIProvider?, aiModel: String, enhance: Bool) -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "Acceptance Test Mode",
            transcriptionProvider: .whisperKit,
            transcriptionModel: "test-whisper",
            presetId: "regular",
            aiProvider: aiProvider,
            aiModel: aiModel,
            aiEnhanceEnabled: enhance
        )
    }

    /// A throwaway file so `audioURL.lastPathComponent` is sensible; the mock
    /// transcriber ignores its contents and `AVURLAsset` duration resolves to 0.
    private func makeTempAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appendingPathComponent("acceptance-\(UUID().uuidString).m4a")
        try Data([0x00, 0x01, 0x02]).write(to: url)
        return url
    }

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: code, httpVersion: nil, headerFields: nil)!
    }

    // MARK: - record → transcribe → enhance → store

    @Test func processedRecording_persistsTranscriptionWithEnhancedTextAndVariation() async throws {
        let container = try TestModelContainer.makeInMemory()
        let defaults = makeDefaults()

        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6", enhance: true)
        let transcriber = MockTranscriber(currentMode: mode, stubbedText: "this is the transcribed text")

        // Enhancement boundary: mocked keychain + network return a known result.
        let keychain = MockKeychainService()
        _ = keychain.save("ANTHROPIC_KEY", forKey: "anthropicAPIKey")
        let net = MockNetworkService()
        net.stubSendResponse = .success((Data(#"{"content":[{"type":"text","text":"Enhanced acceptance output"}]}"#.utf8), http(200)))

        let aiService = AIService(
            userDefaults: defaults,
            keychain: keychain,
            networkService: net,
            oauthManager: MockOAuthManager(),
            cliServerEnhancer: StubCLIServerEnhancer()
        )
        aiService.modes = [mode]
        aiService.selectedMode = mode
        aiService.connectedProviders = [.anthropic]            // satisfies isProperlyConfigured's "connected" branch
        aiService.presetManager = PresetManager(userDefaults: defaults)

        let sut = WatchAudioProcessor(
            transcriptionManager: transcriber,
            aiService: aiService,
            modelContainer: container
        )

        // When: the recording is processed end to end.
        let audioURL = try makeTempAudioFile()
        await sut.processAudioFile(at: audioURL, sourceTag: "test-acceptance")

        // Then: a Transcription with its enhanced variation is persisted.
        let readContext = ModelContext(container)
        let stored = try #require(try readContext.fetch(FetchDescriptor<Transcription>()).first)
        #expect(stored.text == "this is the transcribed text")
        #expect(stored.enhancedText == "Enhanced acceptance output")
        #expect(stored.sourceTag == "test-acceptance")
        #expect(stored.variations?.count == 1)
        let variation = try #require(stored.variations?.first)
        #expect(variation.text == "Enhanced acceptance output")
        #expect(variation.text == stored.enhancedText)          // dual-write stays consistent

        // And: the enhancement really went through the cloud path (not a stub shortcut).
        #expect(net.capturedRequest?.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(net.capturedRequest?.value(forHTTPHeaderField: "x-api-key") == "ANTHROPIC_KEY")
    }

    @Test func processedRecording_whenEnhancementDisabled_persistsRawTranscriptionWithNoVariation() async throws {
        let container = try TestModelContainer.makeInMemory()

        let mode = makeMode(aiProvider: .anthropic, aiModel: "claude-sonnet-4-6", enhance: false)
        let transcriber = MockTranscriber(currentMode: mode, stubbedText: "raw note, no enhancement")

        let net = MockNetworkService()
        let aiService = AIService(
            userDefaults: makeDefaults(),
            keychain: MockKeychainService(),
            networkService: net,
            oauthManager: MockOAuthManager(),
            cliServerEnhancer: StubCLIServerEnhancer()
        )
        aiService.selectedMode = mode

        let sut = WatchAudioProcessor(
            transcriptionManager: transcriber,
            aiService: aiService,
            modelContainer: container
        )

        let audioURL = try makeTempAudioFile()
        await sut.processAudioFile(at: audioURL, sourceTag: "test-acceptance-raw")

        let readContext = ModelContext(container)
        let stored = try #require(try readContext.fetch(FetchDescriptor<Transcription>()).first)
        #expect(stored.text == "raw note, no enhancement")
        #expect(stored.enhancedText == nil)
        #expect(stored.variations?.isEmpty == true)
        #expect(net.capturedRequest == nil)                    // enhancement skipped, no network call
    }
}
