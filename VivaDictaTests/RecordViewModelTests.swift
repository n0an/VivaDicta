//
//  RecordViewModelTests.swift
//  VivaDictaTests
//
//  Created by Anton Novoselov on 2026.03.20
//

import Foundation
import SwiftData
import Testing
import AICore
import AppGroup
import AudioRecording
import AudioRecordingMocks
import Presets
@testable import VivaDicta

/// `RecordViewModel` is now constructible in a test: its AI, transcription,
/// audio, and app-group surfaces are seamed behind protocols
/// (`AIProcessingService` / `Transcriber` / `AudioPrewarmer` / `AppGroupBridge`),
/// so a test injects mocks for all of them. `AppState` stays a real instance -
/// its init boots the service graph, but that is fast and non-fatal under test
/// (the only noise is CloudKit's "no iCloud account"), so no `AppState` seam was
/// needed. The pure-formula tests below predate the seams; the construction test
/// exercises the seamed VM.
struct RecordViewModelTests {

    // MARK: - Audio Level Normalization (pure formula, no VM construction)

    private func normalizeAudioPower(_ power: Double) -> Double {
        min(1, max(0, 1 - abs(power / 50)))
    }

    @Test func audioLevelNormalization_negativePower_clamped() {
        #expect(normalizeAudioPower(-60) == 0)
    }

    @Test func audioLevelNormalization_zeroPower_maxLevel() {
        #expect(normalizeAudioPower(0) == 1.0)
    }

    @Test func audioLevelNormalization_normalRange() {
        #expect(normalizeAudioPower(-25) == 0.5)
    }

    // MARK: - Recording State

    @Test func recordingState_initialValue_idle() {
        let state: RecordingState = .idle
        #expect(state == .idle)
    }

    @Test func recordingState_equatable() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.error(.avInitError) == RecordingState.error(.avInitError))
        #expect(RecordingState.error(.avInitError) != RecordingState.error(.userDenied))
    }

    // MARK: - Construction (now that AI / transcription / audio / app-group are seamed)

    /// Constructs the real `RecordViewModel` with every injected dependency mocked.
    /// `AppState` is still a real instance (its god-object init boots the service
    /// graph), but the four seams mean the VM's own AI/transcription/audio/app-group
    /// surfaces are mock-driven, and the keyboard handlers wire onto the injected
    /// bridge instead of the process-global singleton.
    @MainActor
    @Test func constructsWithMocks_andWiresKeyboardHandlersOntoInjectedBridge() throws {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let appGroup = MockAppGroupBridge()
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: MockTranscriber(),
            aiService: MockAIProcessingService(),
            prewarmManager: MockAudioPrewarmer(),
            appGroupBridge: appGroup
        )

        #expect(sut.recordingState == .idle)
        // Proof the AppGroupBridge seam is effective: setup wired the keyboard
        // control callbacks onto the injected mock, not AppGroupCoordinator.shared.
        #expect(appGroup.onStartRecordingRequested != nil)
        #expect(appGroup.onStopRecordingRequested != nil)
    }

    // MARK: - transcribeSpeechTask flow

    /// Note: the tail of the success path touches a few process-global singletons
    /// that are NOT seamed (ClipboardManager, RecentNotesCache, FolderExportService,
    /// RateAppManager, HapticManager). They are non-fatal and gated under test, so
    /// this is tolerated for now - the next seam candidates if any turns flaky in CI.
    @MainActor
    private func makeSUT(
        transcriber: MockTranscriber,
        aiService: MockAIProcessingService = MockAIProcessingService(),
        appGroup: MockAppGroupBridge = MockAppGroupBridge(),
        audioFileService: AudioFileService = DefaultAudioFileService(),
        audioRecordingService: AudioRecordingService = MockAudioRecordingService(),
        prewarmManager: any AudioPrewarmer = MockAudioPrewarmer()
    ) throws -> (sut: RecordViewModel, container: ModelContainer) {
        // `saveNewTranscription` kicks off fire-and-forget RAGIndexingService vector
        // indexing when SmartSearch is on (default), which would do real LumoKit I/O
        // and leak work past the test. Disable it so the flow stays hermetic.
        SmartSearchFeature.isEnabled = false
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: transcriber,
            aiService: aiService,
            audioRecordingService: audioRecordingService,
            audioFileService: audioFileService,
            prewarmManager: prewarmManager,
            appGroupBridge: appGroup
        )
        return (sut, container)
    }

    /// Parakeet provider so `transcribeSpeechTask` skips the real-audio
    /// downsampling path and goes straight to the mocked `transcribe`.
    private func parakeetMode() -> VivaMode {
        VivaMode(
            id: UUID(),
            name: "Parakeet",
            transcriptionProvider: .parakeet,
            transcriptionModel: "parakeet",
            aiProvider: .openAI,
            aiModel: "gpt-4",
            aiEnhanceEnabled: true
        )
    }

    private func makeDummyAudioFile() throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // "RIFF"
        return url
    }

    @MainActor
    @Test func transcribeSpeechTask_transcribesAndEnhances_persistsAndPushesStatus() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "hello world")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = true
        ai.stubEnhanceResult = .success(("HELLO WORLD enhanced", 0.1, "TestPrompt"))
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 1)
        #expect(appGroup.transcriptionStatuses.contains(.transcribing))
        #expect(appGroup.transcriptionStatuses.contains(.enhancing))

        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "hello world")
        #expect(saved.first?.enhancedText == "HELLO WORLD enhanced")
        #expect(sut.recordingState == .idle) // flow ends idle
    }

    @MainActor
    @Test func transcribeSpeechTask_whenNotConfigured_persistsTranscriptWithoutEnhancing() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "just a note")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = false // -> shouldEnhance is false
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 0)
        #expect(appGroup.transcriptionStatuses.contains(.transcribing))
        #expect(!appGroup.transcriptionStatuses.contains(.enhancing))

        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "just a note")
        #expect(saved.first?.enhancedText == nil)
    }

    private enum FlowTestError: Error { case boom }

    @MainActor
    @Test func transcribeSpeechTask_whenEnhancementFails_persistsTranscriptAndAlerts() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "kept transcript")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = true
        ai.stubEnhanceResult = .failure(FlowTestError.boom)
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(ai.enhanceCallCount == 1)
        // Enhancement failed, but the transcript is still saved (text only) and the
        // user is alerted.
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        #expect(saved.first?.text == "kept transcript")
        #expect(saved.first?.enhancedText == nil)
        #expect(sut.isShowingAlert == true)
        // The right alert is shown, and enhancement failure is non-fatal: the flow
        // still ends idle rather than erroring out.
        if case .aiEnhancement = sut.recordError {} else {
            Issue.record("expected recordError == .aiEnhancement, got \(String(describing: sut.recordError))")
        }
        #expect(sut.recordingState == .idle)
    }

    @MainActor
    @Test func transcribeSpeechTask_whenTranscriptHasNoMeaningfulContent_doesNotPersist() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "   ")
        let ai = MockAIProcessingService()
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(transcriber.transcribeCallCount == 1)
        #expect(ai.enhanceCallCount == 0) // skipped - no meaningful content
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.isEmpty)
        #expect(sut.recordingState == .idle)
        #expect(appGroup.transcriptionStatuses.contains(.idle))
    }

    // MARK: - Transcription failure (issue #384)

    /// A readable audio file the rescue path can measure. The success-path tests
    /// get away with a 4-byte "RIFF" stub because `AVURLAsset` reports 0 on it
    /// rather than throwing; the rescue gates on `fileSize`, so it needs bytes.
    @MainActor
    private func failingFileService(size: Int64 = 4096, duration: TimeInterval = 7) -> MockAudioFileService {
        let fileService = MockAudioFileService()
        fileService.stubFileSize = .success(size)
        fileService.stubDuration = .success(duration)
        fileService.stubRemove = .success(())
        return fileService
    }

    @MainActor
    @Test func transcribeSpeechTask_whenTranscriptionFails_keepsRecordingAsFailedNote() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode())
        transcriber.stubbedError = FlowTestError.boom
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(
            transcriber: transcriber,
            appGroup: appGroup,
            audioFileService: failingFileService()
        )
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        // The recording survives as a note pointing at its audio, so the detail
        // view can play it back and retranscribe it.
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.count == 1)
        let rescued = try #require(saved.first)
        #expect(rescued.text.isEmpty)
        #expect(rescued.audioFileName == audio.lastPathComponent)
        #expect(rescued.audioDuration == 7)
        #expect(rescued.isFailedTranscription)
    }

    @MainActor
    @Test func transcribeSpeechTask_whenTranscriptionFails_alertsWithTheReasonAndReturnsToIdle() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode())
        transcriber.stubbedError = FlowTestError.boom
        let (sut, container) = try makeSUT(
            transcriber: transcriber,
            audioFileService: failingFileService()
        )
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(sut.isShowingAlert == true)
        if case .transcribe(let reason) = sut.recordError {
            #expect(!reason.isEmpty)
        } else {
            Issue.record("expected recordError == .transcribe, got \(String(describing: sut.recordError))")
        }
        // Not parked in `.error`: that state renders nowhere and leaves the
        // append-to-note actions disabled until the next successful recording.
        #expect(sut.recordingState == .idle)
    }

    @MainActor
    @Test func transcribeSpeechTask_whenTranscriptionFailsAndAudioIsGone_savesNothing() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode())
        transcriber.stubbedError = FlowTestError.boom
        let fileService = failingFileService()
        fileService.stubFileSize = .success(0) // nothing on disk to rescue
        let (sut, container) = try makeSUT(
            transcriber: transcriber,
            audioFileService: fileService
        )
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(recordURL: audio, modelContext: container.mainContext).value

        #expect(try container.mainContext.fetch(FetchDescriptor<Transcription>()).isEmpty)
        // The user is still told, even though there was nothing to keep.
        #expect(sut.isShowingAlert == true)
        #expect(sut.recordingState == .idle)
    }

    @MainActor
    @Test func failedTranscription_clearsItsStatusOnceARetrySucceeds() throws {
        let sut = Transcription(text: "", audioDuration: 7, audioFileName: "abc.wav")
        sut.transcriptionStatus = TranscriptionStatus.failed.rawValue
        #expect(sut.isFailedTranscription)

        sut.text = "recovered on retry"
        sut.clearFailedStatus()

        #expect(!sut.isFailedTranscription)
        #expect(sut.transcriptionStatus == TranscriptionStatus.completed.rawValue)
    }

    // MARK: - Audio session interruptions (issue #386)

    @MainActor
    @Test func interruption_whileRecording_finishesTheCaptureAndAlerts() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "cut short")
        let recorder = MockAudioRecordingService()
        let fileService = MockAudioFileService()
        fileService.stubMove = .success(())
        let (sut, container) = try makeSUT(
            transcriber: transcriber,
            audioFileService: fileService,
            audioRecordingService: recorder
        )
        sut.recordingState = .recording

        recorder.fireInterruption()
        await sut.transcribingSpeechTask?.value

        // The partial audio went through the normal stop path rather than being
        // dropped: it was moved into place and transcribed.
        #expect(fileService.moveCallCount == 1)
        #expect(transcriber.transcribeCallCount == 1)
        let saved = try container.mainContext.fetch(FetchDescriptor<Transcription>())
        #expect(saved.first?.text == "cut short")

        // And the user is told why the recording ended early.
        #expect(sut.isShowingAlert == true)
        #expect(sut.recordError == .interrupted)
    }

    @MainActor
    @Test func interruption_whenNotRecording_isIgnored() throws {
        let recorder = MockAudioRecordingService()
        let fileService = MockAudioFileService()
        fileService.stubMove = .success(())
        let (sut, _) = try makeSUT(
            transcriber: MockTranscriber(currentMode: parakeetMode()),
            audioFileService: fileService,
            audioRecordingService: recorder
        )

        // Both capture paths report the same interruption, so the handler has to
        // tolerate arriving with nothing to stop.
        recorder.fireInterruption()

        #expect(fileService.moveCallCount == 0)
        #expect(sut.isShowingAlert == false)
        #expect(sut.recordingState == .idle)
    }

    @MainActor
    @Test func interruption_onTheHotMicPath_closesTheCapture() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "hot mic partial")
        let prewarm = MockAudioPrewarmer()
        prewarm.isSessionActive = true
        let fileService = MockAudioFileService()
        fileService.stubMove = .success(())
        let (sut, _) = try makeSUT(
            transcriber: transcriber,
            audioFileService: fileService,
            prewarmManager: prewarm
        )
        sut.recordingState = .recording

        prewarm.fireInterruption()
        await sut.transcribingSpeechTask?.value

        #expect(prewarm.stopRealCaptureCallCount == 1)
        #expect(sut.recordError == .interrupted)
    }

    // MARK: - Auto Share Note

    /// All three "Auto Share Note" cases share one SUT (and so one `AppState`)
    /// on purpose: standing up a second real `AppState` mid-suite tears down the
    /// first one's CloudKit-backed store ("Stores Changed"), which faults any
    /// model instance the previous case left alive and kills the whole process.
    ///
    /// `autoShareIfEnabled` defers the request so it doesn't race the recording
    /// sheet's dismissal, hence the polling helper rather than a bare read.
    @MainActor
    @Test func autoShare_queuesOnlyForInAppRecordings_andOnlyWhenEnabled() async throws {
        let key = UserDefaultsStorage.Keys.isAutoShareAfterRecordingEnabled
        let previous = UserDefaultsStorage.appPrivate.object(forKey: key)
        defer { UserDefaultsStorage.appPrivate.set(previous, forKey: key) }

        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "shared note")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = false
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai)

        // Off: nothing is queued.
        UserDefaultsStorage.appPrivate.set(false, forKey: key)
        await sut.transcribeSpeechTask(
            recordURL: try makeDummyAudioFile(),
            modelContext: container.mainContext,
            sourceTag: SourceTag.app
        ).value
        #expect(await pendingAutoShare(of: sut) == nil)

        // On, but the recording came from the keyboard - the main app is in the
        // background there, so the sheet must not be queued.
        UserDefaultsStorage.appPrivate.set(true, forKey: key)
        await sut.transcribeSpeechTask(
            recordURL: try makeDummyAudioFile(),
            modelContext: container.mainContext,
            sourceTag: SourceTag.keyboard
        ).value
        #expect(await pendingAutoShare(of: sut) == nil)

        // On, recorded in the app: the transcript is queued for the share sheet.
        await sut.transcribeSpeechTask(
            recordURL: try makeDummyAudioFile(),
            modelContext: container.mainContext,
            sourceTag: SourceTag.app
        ).value
        #expect(await pendingAutoShare(of: sut)?.text == "shared note")
    }

    /// Polls past `autoShareIfEnabled`'s deferral. Returns nil if nothing was
    /// queued within the window, which is what the negative cases assert.
    @MainActor
    private func pendingAutoShare(of sut: RecordViewModel) async -> AutoShareRequest? {
        for _ in 0..<20 {
            if let pending = sut.pendingAutoShare { return pending }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return sut.pendingAutoShare
    }

    // MARK: - Voice Instruction ("Speak to Edit")

    @MainActor
    @Test func voiceInstruction_appliesSpokenInstructionToTargetText_andReturnsItToTheKeyboard() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "make this more formal")
        let ai = MockAIProcessingService()
        ai.stubGenerateVariationResult = .success(("Good afternoon.", 0.2))
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(
            recordURL: audio,
            modelContext: container.mainContext,
            sourceTag: SourceTag.keyboard,
            destination: .voiceInstruction(targetText: "hey whats up", modeName: "Parakeet")
        ).value

        // The transcript is the instruction; the keyboard's text is the input.
        #expect(ai.generateVariationCallCount == 1)
        #expect(ai.lastGenerateVariationText == "hey whats up")
        #expect(ai.lastGenerateVariationPreset?.promptInstructions == "make this more formal")
        // The wrapper carries the "do not answer questions" rule that keeps the
        // model rewriting instead of replying.
        #expect(ai.lastGenerateVariationPreset?.useSystemTemplate == true)
        #expect(appGroup.textProcessingResults == ["Good afternoon."])
        #expect(appGroup.textProcessingErrors.isEmpty)
        #expect(sut.recordingState == .idle)
    }

    @MainActor
    @Test func voiceInstruction_persistsNothing() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "shorten this")
        let ai = MockAIProcessingService()
        ai.stubIsProperlyConfigured = true
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(
            recordURL: audio,
            modelContext: container.mainContext,
            sourceTag: SourceTag.keyboard,
            destination: .voiceInstruction(targetText: "a long paragraph", modeName: "Parakeet")
        ).value

        // No note, and the mode's own AI processing never runs - the instruction
        // replaces it rather than stacking on top of it.
        #expect(try container.mainContext.fetch(FetchDescriptor<Transcription>()).isEmpty)
        #expect(ai.enhanceCallCount == 0)
        // The instruction audio is discarded too.
        #expect(!FileManager.default.fileExists(atPath: audio.path))
    }

    @MainActor
    @Test func voiceInstruction_whenNothingWasSaid_releasesTheKeyboardWithAnError() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "   ")
        let ai = MockAIProcessingService()
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        // The keyboard blocks on a continuation for this whole round trip, so an
        // empty instruction has to fail it rather than go quiet.
        await sut.transcribeSpeechTask(
            recordURL: audio,
            modelContext: container.mainContext,
            sourceTag: SourceTag.keyboard,
            destination: .voiceInstruction(targetText: "untouched", modeName: "Parakeet")
        ).value

        #expect(ai.generateVariationCallCount == 0)
        #expect(appGroup.textProcessingErrors.count == 1)
        #expect(appGroup.textProcessingResults.isEmpty)
    }

    @MainActor
    @Test func voiceInstruction_whenAIFails_releasesTheKeyboardWithAnError() async throws {
        let transcriber = MockTranscriber(currentMode: parakeetMode(), stubbedText: "translate to French")
        let ai = MockAIProcessingService()
        ai.stubGenerateVariationResult = .failure(FlowTestError.boom)
        let appGroup = MockAppGroupBridge()
        let (sut, container) = try makeSUT(transcriber: transcriber, aiService: ai, appGroup: appGroup)
        let audio = try makeDummyAudioFile()

        await sut.transcribeSpeechTask(
            recordURL: audio,
            modelContext: container.mainContext,
            sourceTag: SourceTag.keyboard,
            destination: .voiceInstruction(targetText: "hello there", modeName: "Parakeet")
        ).value

        #expect(appGroup.textProcessingErrors.count == 1)
        #expect(appGroup.textProcessingResults.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<Transcription>()).isEmpty)
    }

    @MainActor
    @Test func voiceInstruction_whenRecordingCannotStart_releasesTheKeyboardInsteadOfHanging() throws {
        let appGroup = MockAppGroupBridge()
        let prewarm = MockAudioPrewarmer()
        prewarm.isSessionActive = false // no session -> recording will not start
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        // Held, not discarded: the handler captures `self` weakly, so a released
        // view model would make this pass without running any of the code.
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: MockTranscriber(),
            aiService: MockAIProcessingService(),
            prewarmManager: prewarm,
            appGroupBridge: appGroup
        )
        appGroup.stubPendingVoiceInstruction = (targetText: "some text", modeName: "Parakeet")

        appGroup.onStartRecordingRequested?()

        // Without this the keyboard would sit on its continuation until the
        // session expiry timeout.
        #expect(appGroup.textProcessingErrors.count == 1)
        withExtendedLifetime(sut) {}
    }

    @MainActor
    @Test func startRecording_withoutAParkedInstruction_staysOnTheOrdinaryNotePath() throws {
        let appGroup = MockAppGroupBridge()
        let prewarm = MockAudioPrewarmer()
        prewarm.isSessionActive = false
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let sut = RecordViewModel(
            appState: AppState(),
            modelContainer: container,
            transcriptionManager: MockTranscriber(),
            aiService: MockAIProcessingService(),
            prewarmManager: prewarm,
            appGroupBridge: appGroup
        )

        appGroup.onStartRecordingRequested?()

        // An ordinary dictation that cannot start must not report on the text
        // processing channel - nothing is waiting there.
        #expect(appGroup.textProcessingErrors.isEmpty)
        withExtendedLifetime(sut) {}
    }
}
