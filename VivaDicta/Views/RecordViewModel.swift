//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import TextProcessing
import Foundation
import AppGroup
import AudioRecording
import TranscriptionCore
import AVFoundation
import SwiftData
import os
import TipKit
import Presets
import AICore
import AIProviders

enum RecordingDestination: Equatable {
    case newNote
    case appendToTranscription(id: UUID)
    /// A spoken rewrite instruction from the keyboard ("speak to edit").
    ///
    /// The transcript is the *instruction*, not the content: it is applied to
    /// `targetText` and handed straight back to the keyboard. Nothing is
    /// enhanced, saved, indexed, or added to Recent Notes along the way.
    case voiceInstruction(targetText: String, modeName: String)
}

/// Text queued for the automatic share sheet after a recording finishes.
///
/// Identity is per-request (a fresh `id` each time) so back-to-back recordings
/// of the same text still re-present the sheet.
struct AutoShareRequest: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

/// Data structure to hold pending transcription when enhancement is in progress.
private struct PendingTranscriptionData {
    let text: String
    let audioDuration: Double
    let audioFileName: String
    let transcriptionModelName: String?
    let transcriptionProviderName: String?
    let transcriptionDuration: TimeInterval
    let modelContext: ModelContext
    let sourceTag: String?
}

/// View model managing audio recording, transcription, and enhancement workflow.
///
/// `RecordViewModel` handles the complete lifecycle of voice recording, from capturing
/// audio to transcribing and optionally enhancing the text. It coordinates with
/// ``TranscriptionManager`` and ``AIService`` through the ``AppState``.
///
/// ## Overview
///
/// The view model manages:
/// - Audio recording via AVAudioRecorder or AudioPrewarmManager (for keyboard flow)
/// - Recording state machine (idle, recording, transcribing, enhancing, error)
/// - Audio level monitoring for visualization
/// - Transcription and AI processing pipeline
/// - Communication with keyboard extension via ``AppGroupCoordinator``
///
/// ## Recording States
///
/// ```
/// idle → recording → transcribing → enhancing → idle
///                  ↘                          ↗
///                    → error → idle (on cancel)
/// ```
///
/// ## Keyboard Integration
///
/// When the keyboard extension activates a session, recording uses a prewarmed
/// audio engine for lower latency. The view model handles start/stop/cancel
/// commands from the keyboard via Darwin notifications.
///
/// ## Usage
///
/// ```swift
/// let viewModel = RecordViewModel(appState: appState, modelContainer: container)
///
/// // Start recording
/// viewModel.startCaptureAudio()
///
/// // Stop and transcribe
/// viewModel.stopCaptureAudio(modelContext: context)
///
/// // Cancel processing
/// viewModel.cancelProcessing()
/// ```
@Observable @MainActor
class RecordViewModel: NSObject, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer!

    private let audioRecordingService: AudioRecordingService
    private let audioFileService: AudioFileService
    private let prewarmManager: any AudioPrewarmer
    private let appGroupBridge: any AppGroupBridge
    private let logger = Logger(category: .recordViewModel)

    var animationTimer: Timer?

    weak var appState: AppState?
    var modelContext: ModelContext

    public let transcriptionManager: any Transcriber
    public let aiService: any AIProcessingService

    var selectedModeName: String {
        get { aiService.selectedModeName }
        set { aiService.selectedModeName = newValue }
    }

    var availableModes: [VivaMode] {
        aiService.modes
    }

    init(
        appState: AppState,
        modelContainer: ModelContainer,
        transcriptionManager: (any Transcriber)? = nil,
        aiService: (any AIProcessingService)? = nil,
        audioRecordingService: AudioRecordingService = DefaultAudioRecordingService(),
        audioFileService: AudioFileService = DefaultAudioFileService(),
        prewarmManager: any AudioPrewarmer = AudioPrewarmManager.shared,
        appGroupBridge: any AppGroupBridge = AppGroupCoordinator.shared
    ) {
        self.appState = appState
        self.transcriptionManager = transcriptionManager ?? appState.transcriptionManager
        self.aiService = aiService ?? appState.aiService
        self.modelContext = ModelContext(modelContainer)
        self.audioRecordingService = audioRecordingService
        self.audioFileService = audioFileService
        self.prewarmManager = prewarmManager
        self.appGroupBridge = appGroupBridge
        super.init()
        self.audioRecordingService.onDidFinishUnsuccessfully = { [weak self] in
            guard let self else { return }
            self.resetValues()
            self.recordingState = .idle
        }
        // Both capture paths can be interrupted, and only one of them is live
        // at a time, so they share a handler. It is idempotent either way.
        self.audioRecordingService.onInterruption = { [weak self] in
            self?.handleRecordingInterrupted()
        }
        self.prewarmManager.onInterruption = { [weak self] in
            self?.handleRecordingInterrupted()
        }
        setupKeyboardRecordingHandlers()
    }

    // Note: No deinit cleanup needed for Darwin observers
    // The AppGroupCoordinator will properly handle duplicate registrations by
    // removing old observers before adding new ones (see AppGroupCoordinator.addObserver)
    
    var transcribingSpeechTask: Task<Void, Never>?
    var transcriptionProgress: TranscriptionProgressInfo?

    // Pending transcription data for saving when enhancement is cancelled
    private var pendingTranscription: PendingTranscriptionData?
    private var activeRecordingDestination: RecordingDestination = .newNote
    private var activeSourceTag: String = SourceTag.app

    /// True from the moment a keyboard voice instruction starts recording until
    /// its rewrite is delivered or failed.
    ///
    /// `activeRecordingDestination` cannot stand in for this: `stopCaptureAudio`
    /// clears it and carries the destination onward as a local, so by the time
    /// the AI call runs there is nothing left to read. The keyboard is blocked
    /// on a continuation for the whole window, so every exit has to release it.
    private var isAwaitingVoiceInstructionResult = false

    /// Non-nil only while a streaming model is recording. Its presence is what
    /// makes stop/cancel take the realtime branch.
    private var realtimeCoordinator: RealtimeDictationCoordinator?
    /// Transcript produced by the realtime socket, handed to
    /// `transcribeSpeechTask` so it skips the upload entirely. Nil means the
    /// normal file-based path runs, including after a realtime failure.
    private var realtimeTranscript: String?

    var captureURL: URL {
        FileManager.appDirectory(for: .audio).appendingPathComponent("recording.wav")
    }
    
    /// Current state of the recording/transcription workflow.
    ///
    /// State transitions are logged and shared with the keyboard extension.
    var recordingState: RecordingState = .idle {
        didSet {
            logger.logInfo("📱 Recording state changed: \(String(describing: self.recordingState))")
            // Recording state is shared with keyboard extension via appGroupBridge.updateRecordingState()
            // which is called in startCaptureAudio(), stopCaptureAudio(), and cancelTranscribe()
        }
    }
    
    var isShowingAlert = false
    var recordError: RecordError = .other

    /// Set when "Auto Share Note" is on and an in-app recording finished, so
    /// ``MainView`` can present the system share sheet. Cleared on dismissal.
    var pendingAutoShare: AutoShareRequest?
    
    var audioPower = 0.0

    /// Tag IDs the user selected while recording, applied to the new `Transcription` on save.
    ///
    /// The transcription does not exist yet during recording, so selections are buffered here
    /// and turned into `TranscriptionTagAssignment` records in ``saveNewTranscription(...)``.
    /// Cleared when a new recording starts, on cancel, and after the assignments are written.
    var pendingTagIds: Set<UUID> = []
    var siriWaveFormOpacity: CGFloat {
        switch recordingState {
        case .recording: return 1
        default: return 0
        }
    }
    
    /// Finishes a recording the system ended for us.
    ///
    /// An interruption is a Stop the user never pressed: a call, an alarm, or
    /// Siri took the microphone, the capture is already closed, and the only
    /// open question is what happens to the audio recorded up to that point.
    /// Running it through the normal stop path transcribes and saves it like
    /// any other recording, which beats dropping however many minutes the user
    /// had already spoken.
    ///
    /// Guarded on `.recording` because both capture paths report the same
    /// interruption and only one of them owns the live capture.
    private func handleRecordingInterrupted() {
        guard recordingState == .recording else { return }

        logger.logInfo("🎙️ Recording interrupted - finishing with the audio captured so far")

        // Queued behind the stop: the alert is informational, and raising it
        // first would fight the sheet that stopping is about to dismiss.
        defer {
            recordError = .interrupted
            isShowingAlert = true
        }

        stopCaptureAudio(modelContext: modelContext)
    }

    /// Surfaces a failed start and hands the UI back to the user.
    ///
    /// Both start paths flip `recordingState` to `.recording` before attempting
    /// the capture, so a throw here has already opened - and is about to close -
    /// the recording sheet. Parking in `.error` left nothing on screen to explain
    /// it and kept the append-to-note actions in the detail view disabled until
    /// the next successful recording, so go back to `.idle` and alert instead.
    private func reportFailedStart() {
        HapticManager.error()
        recordError = .recordError
        isShowingAlert = true
        recordingState = .idle
        appGroupBridge.updateRecordingState(false)
    }

    private func requestMicrophonePermission() async -> Bool {
#if !os(macOS)
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
#else
        true
#endif
    }
    
    
    
    /// Starts audio recording.
    ///
    /// If a keyboard prewarm session is active, uses the prewarmed audio engine.
    /// Otherwise, delegates capture to ``AudioRecordingService``.
    func startCaptureAudio(
        destination: RecordingDestination = .newNote,
        sourceTag: String = SourceTag.app,
        initialTagIds: Set<UUID> = []
    ) {
        Task {
            // Guard against duplicate starts
            guard recordingState != .recording else {
                logger.logInfo("📱 Already recording, ignoring duplicate start request")
                return
            }

            activeSourceTag = sourceTag
            // Clear any stale selection now; the filter-inherited tags are seeded only
            // once capture has actually started, so failed/denied starts leave it empty.
            pendingTagIds.removeAll()
            // Cleared here rather than in resetValues(), which the realtime stop
            // path calls *after* capturing the transcript.
            realtimeTranscript = nil

            // Check if prewarm session is active (keyboard recording)
            if prewarmManager.isSessionActive {
                logger.logInfo("🎙️ Using prewarm session for recording")

                resetValues()
                aiService.captureClipboardContext()
                activeRecordingDestination = destination
                recordingState = .recording
                HapticManager.mediumImpact()

                // Notify keyboard that recording has started
                appGroupBridge.updateRecordingState(true)

                do {
                    // The hot mic is already running, so a streaming model does
                    // not get its own engine here - a second `AVAudioEngine` on
                    // the same input would fight the prewarm session for the
                    // route. The coordinator borrows this one instead: the
                    // prewarm manager keeps writing the WAV exactly as before
                    // and additionally feeds the socket.
                    let modelName = transcriptionManager.getCurrentTranscriptionModel()?.name
                    if let modelName, RealtimeDictationCoordinator.canHandle(
                        mode: transcriptionManager.currentMode,
                        modelName: modelName
                    ) {
                        try await startPrewarmedRealtimeCapture(
                            modelName: modelName,
                            transcriptionLanguage: transcriptionManager.currentMode.transcriptionLanguage ?? "auto"
                        )
                    } else {
                        // Use prewarm manager's AVAudioEngine for recording
                        try prewarmManager.startRealCapture(to: captureURL)
                    }

                    // Recording is live - seed tags inherited from an active filter.
                    pendingTagIds = initialTagIds

                    // Update audio levels from prewarmManager for visualization
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
                        Task { @MainActor in
                            guard let self = self else { return }
                            let level = Double(self.prewarmManager.currentAudioLevel)
                            self.audioPower = level
                            self.appGroupBridge.updateAudioLevel(level)
                        }
                    })

                } catch {
                    logger.logError("🎙️ Failed to start the prewarmed capture: \(error.localizedDescription)")
                    activeRecordingDestination = .newNote
                    resetValues()
                    reportFailedStart()
                    return
                }

            } else {
                // Normal recording flow (not from keyboard)
                logger.logInfo("🎙️ Using normal recording flow")

                
                let hasPermission = await requestMicrophonePermission()
                if !hasPermission {
                    recordError = .userDenied
                    isShowingAlert = true
                    return
                }

                resetValues()
                aiService.captureClipboardContext()
                activeRecordingDestination = destination
                recordingState = .recording
                HapticManager.mediumImpact()

                // Notify keyboard that recording has started (even in normal mode)
                appGroupBridge.updateRecordingState(true)

                do {
                    // Streaming models can't use AVAudioRecorder - it exposes no
                    // buffers to send. They get an engine-backed capture that
                    // writes the same WAV, so the fallback and storage are unaffected.
                    let modelName = transcriptionManager.getCurrentTranscriptionModel()?.name
                    if let modelName, RealtimeDictationCoordinator.canHandle(
                        mode: transcriptionManager.currentMode,
                        modelName: modelName
                    ) {
                        let coordinator = RealtimeDictationCoordinator()

                        // Published BEFORE awaiting start: the state is already
                        // `.recording`, so a Stop or Cancel landing during the
                        // engine spin-up must find the coordinator. Otherwise
                        // stop takes the normal branch and moves the capture
                        // file out from under an engine that is still starting.
                        realtimeCoordinator = coordinator

                        do {
                            try await coordinator.start(
                                writingTo: captureURL,
                                modelName: modelName,
                                transcriptionLanguage: transcriptionManager.currentMode.transcriptionLanguage ?? "auto"
                            )
                        } catch {
                            realtimeCoordinator = nil
                            throw error
                        }

                        // Stop/cancel may have run while start was suspended.
                        guard realtimeCoordinator === coordinator else {
                            logger.logInfo("🎙️ Recording ended during realtime start-up; tearing down")
                            await coordinator.cancel()
                            return
                        }

                        logger.logInfo("🎙️ Recording with realtime streaming transcription")
                    } else {
                        let settings: [String : Any] = [
                            AVFormatIDKey: kAudioFormatLinearPCM,
                            AVSampleRateKey: 16_000.0,
                            AVNumberOfChannelsKey: 1,
                            AVLinearPCMBitDepthKey: 16,
                            AVLinearPCMIsBigEndianKey: false,
                            AVLinearPCMIsFloatKey: false
                        ]

                        try audioRecordingService.startRecording(to: captureURL, settings: settings)
                    }

                    // Recording is live - seed tags inherited from an active filter.
                    pendingTagIds = initialTagIds

                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
                        Task { @MainActor in
                            guard let self else { return }
                            let power: Double
                            if let realtimeCoordinator = self.realtimeCoordinator {
                                power = realtimeCoordinator.currentAudioLevel
                            } else {
                                guard self.audioRecordingService.isRecording else { return }
                                let rawPower = Double(self.audioRecordingService.currentAudioPower)
                                power = min(1, max(0, 1 - abs(rawPower / 50)))
                            }
                            self.audioPower = power
                            self.appGroupBridge.updateAudioLevel(power)
                        }
                    })

                } catch {
                    logger.logError("🎙️ Failed to start recording: \(error.localizedDescription)")
                    activeRecordingDestination = .newNote
                    resetValues()
                    reportFailedStart()
                }
            }
        }
    }
    
    /// Stops audio recording and begins transcription.
    ///
    /// Opens a realtime socket fed by the already-running prewarm engine.
    ///
    /// Falls back to a plain prewarmed capture rather than throwing: the hot mic
    /// is the keyboard's whole reason for existing, and losing the recording
    /// because a socket would not open is a far worse outcome than losing the
    /// speedup. The WAV is written either way, so the fallback is just the
    /// upload path the keyboard used before.
    private func startPrewarmedRealtimeCapture(
        modelName: String,
        transcriptionLanguage: String
    ) async throws {
        let coordinator = RealtimeDictationCoordinator()

        // Published BEFORE awaiting start, for the same reason as the normal
        // path: a Stop landing during socket setup must find the coordinator.
        realtimeCoordinator = coordinator

        do {
            try await coordinator.start(
                writingTo: captureURL,
                modelName: modelName,
                transcriptionLanguage: transcriptionLanguage,
                prewarmedBy: prewarmManager
            )
            logger.logInfo("🎙️ Recording with realtime streaming over the prewarmed engine")
        } catch {
            realtimeCoordinator = nil
            logger.logWarning("🎙️ Realtime start failed on the prewarmed engine, recording normally: \(error.localizedDescription)")
            // `startRealCapture` may have armed the tap before failing, and
            // arming twice would leak the first file handle.
            prewarmManager.stopRealCapture()
            try prewarmManager.startRealCapture(to: captureURL)
        }
    }

    /// - Parameter modelContext: The SwiftData context for saving the transcription.
    func stopCaptureAudio(modelContext: ModelContext) {
        HapticManager.mediumImpact()
        let destination = activeRecordingDestination
        let sourceTag = activeSourceTag
        activeRecordingDestination = .newNote
        activeSourceTag = SourceTag.app

        // Stop real recorder if in prewarm mode (dummy continues running)
        if prewarmManager.isSessionActive {
            logger.logInfo("🎙️ Stopping real capture in prewarm mode (dummy continues)")
            // Always first: this disarms the tap and closes the PCM stream, so
            // the pump feeding the socket drains everything recorded before the
            // end-of-audio marker goes out.
            prewarmManager.stopRealCapture()

            let streamingCoordinator = realtimeCoordinator
            self.realtimeCoordinator = nil

            if let streamingCoordinator {
                // Leave `.recording` before awaiting the flush - a second Stop
                // tap would otherwise move the capture file out from under this.
                recordingState = .transcribing
                appGroupBridge.updateRecordingState(false)
            }

            // In prewarm mode, we need a small delay to ensure file is flushed to disk
            // before trying to move it
            transcribingSpeechTask = Task {
                try? await Task.sleep(for: .milliseconds(100))

                if let streamingCoordinator {
                    do {
                        realtimeTranscript = try await streamingCoordinator.finish()
                        logger.logInfo("🎙️ Realtime transcript ready at stop (prewarmed)")
                    } catch {
                        realtimeTranscript = nil
                        logger.logWarning("🎙️ Realtime transcription failed, falling back to upload: \(error.localizedDescription)")
                    }

                    guard !Task.isCancelled else {
                        await streamingCoordinator.cancel()
                        return
                    }
                }

                resetValues()

                // Notify keyboard that recording has stopped
                appGroupBridge.updateRecordingState(false)

                let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).wav")
                do {
                    try audioFileService.move(from: captureURL, to: finalURL)
                    transcribingSpeechTask = transcribeSpeechTask(
                        recordURL: finalURL,
                        modelContext: modelContext,
                        sourceTag: sourceTag,
                        destination: destination
                    )
                } catch {
                    logger.logError("📱 Failed to move audio file: \(error.localizedDescription)")
                }
            }
        } else if let realtimeCoordinator {
            // Realtime mode: close the socket and collect the transcript before
            // touching the file. The WAV was written all along, so any failure
            // here just falls through to the normal upload path below.
            self.realtimeCoordinator = nil

            // Leave `.recording` before awaiting the flush, which can take up
            // to the finalize timeout. Staying in `.recording` would keep Stop
            // enabled, and a second tap would take the normal branch and move
            // the capture file out from under this task.
            recordingState = .transcribing
            appGroupBridge.updateRecordingState(false)

            // Held in `transcribingSpeechTask` so `cancelTranscribe()` can
            // actually cancel the flush; an untracked task would keep running
            // and save a transcription the user already cancelled.
            transcribingSpeechTask = Task {
                do {
                    realtimeTranscript = try await realtimeCoordinator.finish()
                    logger.logInfo("🎙️ Realtime transcript ready at stop")
                } catch {
                    realtimeTranscript = nil
                    logger.logWarning("🎙️ Realtime transcription failed, falling back to upload: \(error.localizedDescription)")
                }

                guard !Task.isCancelled else {
                    await realtimeCoordinator.cancel()
                    return
                }

                resetValues()
                finishRecording(sourceTag: sourceTag, destination: destination, modelContext: modelContext)
            }
        } else {
            // Normal mode
            resetValues()

            // Notify keyboard that recording has stopped
            appGroupBridge.updateRecordingState(false)

            finishRecording(sourceTag: sourceTag, destination: destination, modelContext: modelContext)
        }
    }

    /// Moves the capture file into place and kicks off transcription. Shared by
    /// the normal and realtime paths so both persist audio identically.
    private func finishRecording(
        sourceTag: String,
        destination: RecordingDestination,
        modelContext: ModelContext
    ) {
        let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).wav")
        do {
            try audioFileService.move(from: captureURL, to: finalURL)
            transcribingSpeechTask = transcribeSpeechTask(
                recordURL: finalURL,
                modelContext: modelContext,
                sourceTag: sourceTag,
                destination: destination
            )
        } catch {
            logger.logError("📱 Failed to move audio file: \(error.localizedDescription)")
        }
    }
    
    func transcribeSpeechTask(
        recordURL: URL,
        modelContext: ModelContext,
        sourceTag: String? = nil,
        destination: RecordingDestination = .newNote
    ) -> Task<Void, Never> {
        Task {
            // Begin background task to allow transcription to complete if user switches apps
            let bgTaskID = appState?.backgroundTaskService.beginBackgroundTask(
                name: "transcription",
                onExpiration: {
                    // Background time expired - transcription will be interrupted
                    // The audio file remains on disk for orphan recovery on next launch
                }
            ) ?? .invalid
            defer { appState?.backgroundTaskService.endBackgroundTask(bgTaskID) }

            // Declared outside the do block so the catch knows which file is
            // actually on disk - downsampling deletes the original and swaps in
            // the 16kHz copy, and the rescue below has to save the survivor.
            var audioURLToTranscribe = recordURL

            do {
                self.recordingState = .transcribing
                self.transcriptionProgress = nil

                // The destination is the authority on whether a keyboard is
                // blocked on this run, so re-arm from it rather than relying on
                // the start handler having done so.
                if case .voiceInstruction = destination {
                    self.isAwaitingVoiceInstructionResult = true
                }

                // Notify keyboard that transcription has started
                appGroupBridge.updateTranscriptionStatus(.transcribing)

                if transcriptionManager.currentMode.transcriptionProvider == .parakeet {
                    logger.logInfo("🎙️ Skipping pre-downsampling for Parakeet because FluidAudio handles file conversion internally")
                } else {
                    // Check if file needs downsampling (keyboard recordings are 48kHz)
                    let tempFile = try AVAudioFile(forReading: recordURL)
                    let sampleRate = tempFile.processingFormat.sampleRate

                    if sampleRate > 16000 {
                        logger.logInfo("🎙️ Detected high sample rate (\(Int(sampleRate))Hz), downsampling to 16kHz")
                        // Use .wav extension for cross-platform PCM support
                        let downsampledURL = recordURL.deletingPathExtension().appendingPathExtension("16k.wav")

                        do {
                            try await audioFileService.downsampleTo16kHzMono(from: recordURL, to: downsampledURL)

                            // Verify the output file was created and has content
                            let fileSize = try audioFileService.fileSize(at: downsampledURL)

                            if fileSize > 1000 {  // At least 1KB
                                // Delete original high-rate file to save space
                                try? audioFileService.remove(at: recordURL)

                                // Use downsampled file for transcription
                                audioURLToTranscribe = downsampledURL
                                logger.logInfo("🎙️ Downsampling complete, file size: \(fileSize) bytes, saved ~\(Int((1.0 - 16000.0/sampleRate) * 100))% space")
                            } else {
                                logger.logWarning("🎙️ Downsampled file too small (\(fileSize) bytes), using original")
                                try? audioFileService.remove(at: downsampledURL)
                            }
                        } catch {
                            logger.logWarning("🎙️ Downsampling failed, using original file: \(error.localizedDescription)")
                            // Continue with original file if downsampling fails
                        }
                    }
                }

                // Check for cancellation before starting transcription
                try Task.checkCancellation()

                let transcriptionStart = Date()
                let transcribedText: String
                if let streamed = realtimeTranscript {
                    // Realtime already produced the text while recording; run it
                    // through the same filters/formatting the upload path uses.
                    realtimeTranscript = nil
                    transcribedText = transcriptionManager.postProcessStreamedText(streamed, startTime: transcriptionStart)
                } else {
                    transcribedText = try await transcriptionManager.transcribe(
                        audioURL: audioURLToTranscribe,
                        progressHandler: { progress in
                            await MainActor.run {
                                self.transcriptionProgress = progress
                            }
                        }
                    )
                }
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                // Check for cancellation after transcription
                try Task.checkCancellation()

                // Validate transcription has meaningful content (not empty, whitespace-only, or punctuation-only)
                guard TranscriptionOutputFilter.hasMeaningfulContent(transcribedText) else {
                    logger.logInfo("📱 Transcription contains no meaningful content, skipping save")

                    // Clean up audio file
                    try? audioFileService.remove(at: audioURLToTranscribe)

                    // The keyboard is blocked awaiting a rewrite; an empty
                    // instruction never produces one, so release it here.
                    failPendingVoiceInstruction("Didn't catch an instruction. Try again.")

                    // Reset state
                    resetValues()
                    aiService.clearCapturedClipboard()
                    recordingState = .idle
                    appGroupBridge.updateRecordingState(false)
                    appGroupBridge.updateTranscriptionStatus(.idle)
                    return
                }

                // The spoken text is an instruction, not content: apply it to the
                // keyboard's text and hand the result back. Deliberately ahead of
                // the enhance/save/index block below, none of which should run.
                if case .voiceInstruction(let targetText, let modeName) = destination {
                    await applyVoiceInstruction(
                        instruction: transcribedText,
                        to: targetText,
                        modeName: modeName,
                        audioURL: audioURLToTranscribe
                    )
                    return
                }

                let audioAsset = AVURLAsset(url: audioURLToTranscribe)
                let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                var enhancedText: String? = nil
                var promptName: String? = nil
                var enhancementDur: TimeInterval? = nil
                let resolvedSourceTag = sourceTag ?? SourceTag.app
                let shouldEnhance = destination == .newNote && aiService.isProperlyConfigured()

                // Check if AI Processing is properly configured
                if shouldEnhance {
                    // Check for cancellation before starting enhancement
                    try Task.checkCancellation()

                    // Store pending transcription data before starting enhancement
                    // This allows saving the transcription if enhancement is cancelled
                    self.pendingTranscription = PendingTranscriptionData(
                        text: transcribedText,
                        audioDuration: audioDuration,
                        audioFileName: audioURLToTranscribe.lastPathComponent,
                        transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                        transcriptionProviderName: transcriptionManager.currentMode.transcriptionProvider.displayName,
                        transcriptionDuration: transcriptionDuration,
                        modelContext: modelContext,
                        sourceTag: resolvedSourceTag
                    )

                    // Update state to show enhancing animation
                    self.transcriptionProgress = nil
                    self.recordingState = .enhancing
                    HapticManager.lightImpact()

                    // Notify keyboard that AI processing has started
                    appGroupBridge.updateTranscriptionStatus(.enhancing)

                    do {
                        let (enhanced, enhancementDuration, prompt) = try await aiService.enhance(transcribedText)

                        enhancedText = enhanced
                        promptName = prompt
                        enhancementDur = enhancementDuration

                        // Clear pending data after successful enhancement
                        self.pendingTranscription = nil

                    } catch let error as AppleFoundationModelError {
                        // Apple Foundation Model specific error
                        self.pendingTranscription = nil

                        // Show alert for guardrail violations and refusals so user knows why enhancement failed
                        switch error {
                        case .guardrailViolation:
                            self.recordError = .aiGuardrail
                            self.isShowingAlert = true
                        case .refusal(let reason):
                            self.recordError = .aiRefusal(reason)
                            self.isShowingAlert = true
                        default:
                            break
                        }
                    } catch is CancellationError {
                        // Enhancement was cancelled - don't save, just let the outer handler deal with it
                        self.pendingTranscription = nil
                        throw CancellationError()
                    } catch {
                        // Other enhancement errors - show alert to user
                        self.pendingTranscription = nil
                        self.recordError = .aiEnhancement(error.localizedDescription)
                        self.isShowingAlert = true
                    }
                }
                
                let savedTranscription: Transcription
                let textToShare: String

                switch destination {
                case .newNote:
                    savedTranscription = try saveNewTranscription(
                        transcribedText: transcribedText,
                        enhancedText: enhancedText,
                        promptName: promptName,
                        enhancementDur: enhancementDur,
                        audioURL: audioURLToTranscribe,
                        audioDuration: audioDuration,
                        transcriptionDuration: transcriptionDuration,
                        modelContext: modelContext,
                        sourceTag: resolvedSourceTag
                    )
                    textToShare = enhancedText ?? transcribedText

                case .appendToTranscription(id: let transcriptionID):
                    savedTranscription = try appendTranscribedText(
                        transcribedText,
                        to: transcriptionID,
                        audioURL: audioURLToTranscribe,
                        modelContext: modelContext,
                        audioDuration: audioDuration,
                        transcriptionDuration: transcriptionDuration,
                        sourceTag: resolvedSourceTag
                    )
                    textToShare = transcribedText

                case .voiceInstruction:
                    // Unreachable: the voice instruction path returns well above
                    // this, before any enhance or save work. Bail out rather than
                    // trap if that ever stops being true.
                    logger.logError("🗣️ Voice instruction reached the save switch - skipping save")
                    return
                }

                // Auto-copy to clipboard if enabled
                if UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isAutoCopyAfterRecordingEnabled) {
                    ClipboardManager.copyToClipboard(textToShare)
                }

                // Must run BEFORE shareTranscribedText: if source is .keyboard we
                // publish to the App Group, and the keyboard extension consumes
                // that payload inside handleTranscription (which fires from the
                // Darwin notification shareTranscribedText posts).
                self.openObsidianIfEnabled(text: textToShare, presetName: promptName, sourceTag: resolvedSourceTag)

                FolderExportService.saveIfEnabled(
                    transcription: savedTranscription,
                    mode: aiService.selectedMode
                )

                appGroupBridge.shareTranscribedText(textToShare)

                // Cache for keyboard "Recent Notes" feature
                RecentNotesCache.addNote(
                    id: savedTranscription.id.uuidString,
                    text: savedTranscription.enhancedText ?? savedTranscription.text,
                    timestamp: savedTranscription.timestamp
                )

                HapticManager.heartbeat()
                self.recordingState = .idle
                self.aiService.clearCapturedClipboard()

                self.autoShareIfEnabled(text: textToShare, sourceTag: resolvedSourceTag)

                // Request app rating after successful transcription
                RateAppManager.requestReviewIfAppropriate()

                // Reschedule session timeout now that all processing is complete
                self.prewarmManager.rescheduleSessionTimeout()

            } catch {
                self.aiService.clearCapturedClipboard()
                if Task.isCancelled {
                    self.recordingState = .idle
                    return
                }
                HapticManager.error()

                let reason = error.localizedDescription
                logger.logError("📱 Transcription failed: \(reason)")

                // Notify keyboard of error. A voice instruction is awaiting a text
                // processing result, not a transcription, so it needs the other channel.
                let wasVoiceInstruction = failPendingVoiceInstruction("Transcription failed: \(reason)")
                if !wasVoiceInstruction {
                    appGroupBridge.updateTranscriptionError("Transcription failed: \(reason)")
                }

                if wasVoiceInstruction {
                    // The audio is a rewrite instruction, not content. It has no
                    // note to belong to, so discard it the way the successful and
                    // empty-instruction paths do rather than orphan it on disk.
                    try? audioFileService.remove(at: audioURLToTranscribe)
                } else {
                    await saveFailedTranscription(
                        audioURL: audioURLToTranscribe,
                        modelContext: modelContext,
                        sourceTag: sourceTag ?? SourceTag.app
                    )
                }

                resetValues()

                recordError = .transcribe(reason)
                isShowingAlert = true

                // Back to idle rather than parking in `.error`: nothing renders
                // that state, and the append-to-note actions in the detail view
                // stay disabled for as long as it sticks.
                recordingState = .idle
                appGroupBridge.updateRecordingState(false)

                // Reschedule session timeout even on error
                self.prewarmManager.rescheduleSessionTimeout()
            }
        }
    }
    
    // MARK: - Voice Instruction ("Speak to Edit")

    /// Applies a spoken rewrite instruction to the keyboard's text and returns the
    /// result over the app-group text processing channel.
    ///
    /// The instruction is wrapped in an ephemeral ``Preset`` so it runs through the
    /// same system-prompt template the tapped presets use. That wrapper is what
    /// stops the model *answering* "make this shorter" conversationally instead of
    /// rewriting the text. Nothing survives the call: the preset is never saved, no
    /// ``Transcription`` is created, and the instruction audio is discarded.
    private func applyVoiceInstruction(
        instruction: String,
        to targetText: String,
        modeName: String,
        audioURL: URL
    ) async {
        defer {
            isAwaitingVoiceInstructionResult = false
            try? audioFileService.remove(at: audioURL)
            resetValues()
            aiService.clearCapturedClipboard()
            recordingState = .idle
            appGroupBridge.updateRecordingState(false)
            appGroupBridge.updateTranscriptionStatus(.idle)
            prewarmManager.rescheduleSessionTimeout()
        }

        logger.logInfo("🗣️ Applying voice instruction (\(instruction.count) chars) to \(targetText.count) chars with mode: \(modeName)")

        recordingState = .enhancing
        appGroupBridge.updateTranscriptionStatus(.enhancing)
        // The keyboard is blocked on this round trip - keep the session alive
        // for it the same way the tapped-preset path does.
        appGroupBridge.refreshKeyboardSessionExpiry(timeoutSeconds: prewarmManager.audioSessionTimeout)

        do {
            let (result, _) = try await aiService.generateVariation(
                text: targetText,
                preset: Self.voiceInstructionPreset(instruction: instruction),
                modeOverride: aiService.getMode(name: modeName),
                onPartialResult: nil
            )
            guard !result.isEmpty else {
                logger.logError("🗣️ Voice instruction returned empty result")
                failPendingVoiceInstruction("AI returned empty result")
                return
            }
            // A cancel that landed mid-call already released the keyboard. Delivering
            // now would rewrite text the user just backed out of.
            guard isAwaitingVoiceInstructionResult else {
                logger.logInfo("🗣️ Voice instruction result discarded - cancelled while generating")
                return
            }
            isAwaitingVoiceInstructionResult = false
            appGroupBridge.shareTextProcessingResult(result)
        } catch {
            logger.logError("🗣️ Voice instruction failed: \(error.localizedDescription)")
            failPendingVoiceInstruction(error.localizedDescription)
        }
    }

    /// Releases the keyboard from an in-flight voice instruction round trip.
    ///
    /// Returns `true` when there was one to release, so callers can fall through
    /// to the ordinary transcription error channel when there wasn't.
    @discardableResult
    private func failPendingVoiceInstruction(_ message: String) -> Bool {
        guard isAwaitingVoiceInstructionResult else { return false }
        isAwaitingVoiceInstructionResult = false
        appGroupBridge.shareTextProcessingError(message)
        return true
    }

    /// A throwaway preset carrying one spoken instruction.
    ///
    /// `useSystemTemplate` is on so the instruction lands inside the standard
    /// enhancer wrapper (which carries the "do not answer questions" rule) rather
    /// than becoming a bare system message the model may treat as a chat prompt.
    private static func voiceInstructionPreset(instruction: String) -> Preset {
        Preset(
            id: "voice_instruction",
            name: "Voice Instruction",
            icon: "mic.fill",
            category: "Rewrite",
            promptInstructions: instruction,
            useSystemTemplate: true
        )
    }

    func playAudio(data: Data) throws {
        self.recordingState = .transcribing
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer.isMeteringEnabled = true
        audioPlayer.delegate = self
        audioPlayer.play()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
            Task { @MainActor in
                guard self?.audioPlayer != nil else { return }
                self?.audioPlayer.updateMeters()
                if let audioPlayer = self?.audioPlayer {
                    let power = min(1, max(0, 1 - abs(Double(audioPlayer.averagePower(forChannel: 0)) / 160) ))
                    self?.audioPower = power
                    self?.appGroupBridge.updateAudioLevel(power)
                }
            }
        })
    }
    
    /// Cancels the current recording or transcription without saving.
    func cancelTranscribe() {
        HapticManager.lightImpact()

        transcribingSpeechTask?.cancel()
        transcribingSpeechTask = nil
        pendingTranscription = nil
        activeRecordingDestination = .newNote
        activeSourceTag = SourceTag.app
        pendingTagIds.removeAll()
        failPendingVoiceInstruction("Cancelled")

        // Stop real capture if still recording
        if prewarmManager.isSessionActive && prewarmManager.audioEngine?.isRunning == true {
            logger.logInfo("🎙️ Stopping real capture on cancel")
            prewarmManager.stopRealCapture()
        }

        // Tear down the streaming engine and socket too - resetValues() only
        // knows about AVAudioRecorder, so without this the mic and WebSocket
        // would stay live after a cancel.
        if let realtimeCoordinator {
            self.realtimeCoordinator = nil
            logger.logInfo("🎙️ Cancelling realtime dictation")
            Task { await realtimeCoordinator.cancel() }
        }
        realtimeTranscript = nil

        resetValues()
        recordingState = .idle

        // Notify keyboard that recording was canceled
        appGroupBridge.updateRecordingState(false)
        appGroupBridge.updateTranscriptionStatus(.idle)

        // Reschedule session timeout after cancellation
        prewarmManager.rescheduleSessionTimeout()
    }

    /// Cancels processing with smart behavior based on current state.
    ///
    /// - **Transcribing**: Cancels everything; no data is saved.
    /// - **Enhancing**: Saves the transcription without enhancement.
    func cancelProcessing() {
        aiService.clearCapturedClipboard()
        switch recordingState {
        case .transcribing:
            // Cancel during transcribing - don't save anything
            logger.logInfo("📱 Cancelling transcription - no data will be saved")
            cancelTranscribe()

        case .enhancing:
            // Cancel during enhancing - save transcription without enhancement
            logger.logInfo("📱 Cancelling enhancement - saving transcription without enhancement")

            // Cancel the task first
            transcribingSpeechTask?.cancel()
            transcribingSpeechTask = nil

            // Save the pending transcription if available and has meaningful content
            // Clear immediately to prevent double-save if cancel is called rapidly
            if let pending = pendingTranscription {
                pendingTranscription = nil

                // Skip saving if transcription has no meaningful content
                guard TranscriptionOutputFilter.hasMeaningfulContent(pending.text) else {
                    logger.logInfo("📱 Pending transcription contains no meaningful content, skipping save")
                    resetValues()
                    recordingState = .idle
                    appGroupBridge.updateRecordingState(false)
                    appGroupBridge.updateTranscriptionStatus(.idle)
                    return
                }

                let transcription = Transcription(
                    text: pending.text,
                    enhancedText: nil,
                    audioDuration: pending.audioDuration,
                    audioFileName: pending.audioFileName,
                    transcriptionModelName: pending.transcriptionModelName,
                    transcriptionProviderName: pending.transcriptionProviderName,
                    aiEnhancementModelName: nil,
                    aiProviderName: nil,
                    promptName: nil,
                    transcriptionDuration: pending.transcriptionDuration,
                    enhancementDuration: nil,
                    powerModeId: aiService.selectedMode.id.uuidString,
                    sourceTag: pending.sourceTag
                )

                pending.modelContext.insert(transcription)
                applyPendingTags(to: transcription, modelContext: pending.modelContext)
                do {
                    try pending.modelContext.save()
                    logger.logInfo("📱 Saved transcription without enhancement")
                    Task { await ChatsDiscoveryTip.transcriptionCreatedEvent.donate() }
                    scheduleAutomaticReminderExtractionIfNeeded(
                        for: transcription,
                        modelContext: pending.modelContext
                    )

                    // Haptic feedback for successful save
                    HapticManager.heartbeat()

                    // Index to Spotlight (AppState method is @concurrent - runs off MainActor)
                    let transcriptionEntity = transcription.entity
                    Task {
                        await self.appState?.indexTranscriptionEntityToSpotlight(transcriptionEntity)
                    }

                    // Index for RAG Smart Search
                    Task { await RAGIndexingService.shared.indexTranscription(transcription) }

                    // Auto-copy to clipboard if enabled
                    if UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isAutoCopyAfterRecordingEnabled) {
                        ClipboardManager.copyToClipboard(pending.text)
                    }

                    // Must run BEFORE shareTranscribedText - see rationale in
                    // the enhanced-text path above.
                    self.openObsidianIfEnabled(
                        text: pending.text,
                        presetName: nil,
                        sourceTag: pending.sourceTag ?? SourceTag.app
                    )

                    FolderExportService.saveIfEnabled(
                        transcription: transcription,
                        mode: aiService.selectedMode
                    )

                    // Share with keyboard
                    appGroupBridge.shareTranscribedText(pending.text)

                    // Cache for keyboard "Recent Notes" feature
                    RecentNotesCache.addNote(
                        id: transcription.id.uuidString,
                        text: pending.text,
                        timestamp: transcription.timestamp
                    )

                    // Request app rating after successful transcription
                    RateAppManager.requestReviewIfAppropriate()

                    self.autoShareIfEnabled(
                        text: pending.text,
                        sourceTag: pending.sourceTag ?? SourceTag.app
                    )
                } catch {
                    HapticManager.error()
                    logger.logError("📱 Failed to save transcription: \(error.localizedDescription)")
                }
            }

            // A voice instruction never sets `pendingTranscription`, so it falls
            // through the save block above with the keyboard still blocked.
            failPendingVoiceInstruction("Cancelled")

            resetValues()
            recordingState = .idle

            // Notify keyboard
            appGroupBridge.updateRecordingState(false)
            appGroupBridge.updateTranscriptionStatus(.idle)

            // Reschedule session timeout after cancellation
            prewarmManager.rescheduleSessionTimeout()

        default:
            // For other states, just use regular cancel (which also reschedules timeout)
            cancelTranscribe()
        }
    }

    /// If the active mode has Obsidian save enabled, arrange for
    /// `obsidian://new?...&clipboard&append=true` to open with the correct
    /// clipboard payload.
    ///
    /// Branches on the source tag rather than `UIApplication.applicationState`:
    /// - `.app` (main-app recording): main app is foregrounded, so it writes
    ///   the clipboard and calls `UIApplication.shared.open` directly.
    /// - `.keyboard` (keyboard-triggered, including Hot Mic): main app
    ///   publishes URL + clipboard text to the App Group and does NOT touch
    ///   the clipboard. The keyboard extension consumes both in
    ///   `handleTranscription`, writes the clipboard from its (foregrounded
    ///   host) context, and opens the URL via SwiftUI's `openURL`.
    ///   Background `UIPasteboard` writes from the main app are unreliable
    ///   and would otherwise leak stale Universal Clipboard content into
    ///   Obsidian.
    ///
    /// Callers must invoke this BEFORE `shareTranscribedText`, because the
    /// latter posts a Darwin notification that wakes the keyboard's
    /// `handleTranscription` - which needs the App Group payload in place.
    private func openObsidianIfEnabled(text: String, presetName: String?, sourceTag: String) {
        guard UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isObsidianGloballyEnabled) else { return }
        let mode = aiService.selectedMode
        guard mode.obsidianEnabled else { return }
        // Trim and fall back to the default if the user cleared the field -
        // an empty note name would silently fail to build a URL.
        let trimmedTemplate = (UserDefaultsStorage.appPrivate.string(forKey: UserDefaultsStorage.Keys.obsidianNoteTemplate) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let template = trimmedTemplate.isEmpty ? UserDefaultsStorage.defaultObsidianNoteTemplate : trimmedTemplate
        guard let output = ObsidianURLBuilder.build(text: text, template: template, modeName: mode.name, presetName: presetName) else {
            logger.logError("📱 Obsidian: failed to build URL for mode '\(mode.name)'")
            return
        }
        if sourceTag == SourceTag.keyboard {
            logger.logInfo("📱 Obsidian: delegating to keyboard \(output.url.absoluteString)")
            appGroupBridge.setPendingObsidianHandoff(url: output.url, clipboardText: output.clipboardText)
        } else {
            logger.logInfo("📱 Obsidian: opening directly \(output.url.absoluteString)")
            ClipboardManager.copyToClipboard(output.clipboardText)
            UIApplication.shared.open(output.url)
        }
    }

    /// Queues the system share sheet for a freshly finished recording when
    /// "Auto Share Note" is enabled.
    ///
    /// Only in-app recordings qualify: a keyboard, Watch, or extension recording
    /// finishes with the main app in the background, where the sheet would either
    /// be invisible or ambush the user the next time they foreground the app.
    ///
    /// Presentation is deferred by one short beat because the recording sheet may
    /// still be animating away - SwiftUI silently drops a second presentation that
    /// starts while the first is dismissing.
    private func autoShareIfEnabled(text: String, sourceTag: String) {
        guard sourceTag == SourceTag.app else { return }
        guard UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isAutoShareAfterRecordingEnabled) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.pendingAutoShare = AutoShareRequest(text: text)
        }
    }

    private func saveNewTranscription(
        transcribedText: String,
        enhancedText: String?,
        promptName: String?,
        enhancementDur: TimeInterval?,
        audioURL: URL,
        audioDuration: Double,
        transcriptionDuration: TimeInterval?,
        modelContext: ModelContext,
        sourceTag: String?
    ) throws -> Transcription {
        let transcription = Transcription(
            text: transcribedText,
            enhancedText: enhancedText,
            audioDuration: audioDuration,
            audioFileName: audioURL.lastPathComponent,
            transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
            transcriptionProviderName: transcriptionManager.currentMode.transcriptionProvider.displayName,
            aiEnhancementModelName: enhancedText != nil ? aiService.selectedMode.aiModel : nil,
            aiProviderName: enhancedText != nil ? aiService.selectedMode.aiProvider?.displayName : nil,
            promptName: promptName,
            transcriptionDuration: transcriptionDuration,
            enhancementDuration: enhancementDur,
            powerModeId: aiService.selectedMode.id.uuidString,
            sourceTag: sourceTag
        )

        modelContext.insert(transcription)

        applyPendingTags(to: transcription, modelContext: modelContext)

        if let enhancedText {
            let variation = TranscriptionVariation(
                presetId: aiService.selectedMode.presetId ?? "regular",
                presetDisplayName: promptName ?? "Regular",
                text: enhancedText,
                aiModelName: aiService.selectedMode.aiModel,
                aiProviderName: aiService.selectedMode.aiProvider?.displayName,
                processingDuration: enhancementDur,
                aiRequestSystemMessage: aiService.lastSystemMessageSent,
                aiRequestUserMessage: aiService.lastUserMessageSent
            )
            variation.transcription = transcription
            modelContext.insert(variation)
        }

        try modelContext.save()

        Task { await ChatsDiscoveryTip.transcriptionCreatedEvent.donate() }

        let transcriptionEntity = transcription.entity
        Task {
            await self.appState?.indexTranscriptionEntityToSpotlight(transcriptionEntity)
        }

        Task { await RAGIndexingService.shared.indexTranscription(transcription) }

        if let appState {
            let activity = appState.userActivity(for: transcription)
            activity.becomeCurrent()
        }

        scheduleAutomaticReminderExtractionIfNeeded(
            for: transcription,
            modelContext: modelContext
        )

        return transcription
    }

    /// Saves a placeholder note for a recording whose transcription threw.
    ///
    /// Without this the WAV stays in `Documents/Audio` with nothing pointing at
    /// it: unreachable from the app (the Documents folder is not exposed in
    /// Files), invisible to ``AudioCleanupService`` - which only walks audio
    /// referenced by a ``Transcription`` - and therefore lost for good.
    ///
    /// The note carries no text, which is what ``Transcription/transcriptionStatus``
    /// marks as ``TranscriptionStatus/failed``: the list and detail view label it
    /// as a failed recording, and the detail view's existing retranscribe button
    /// retries it off ``Transcription/audioFileName``.
    ///
    /// Deliberately not indexed to Spotlight or RAG - there is no text to index
    /// until a retry succeeds.
    @discardableResult
    private func saveFailedTranscription(
        audioURL: URL,
        modelContext: ModelContext,
        sourceTag: String?
    ) async -> Transcription? {
        // Existence, not readability, is the gate: a note pointing at audio that
        // AVFoundation happens to choke on is still worth keeping, because the
        // user can play it back and retry. Only an absent or empty file has
        // nothing to rescue.
        let fileSize = (try? audioFileService.fileSize(at: audioURL)) ?? 0
        guard fileSize > 0 else {
            logger.logError("📱 Cannot rescue the failed recording - audio is missing or empty")
            return nil
        }

        let audioDuration = (try? await audioFileService.duration(of: audioURL)) ?? 0

        let transcription = Transcription(
            text: "",
            audioDuration: audioDuration,
            audioFileName: audioURL.lastPathComponent,
            transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
            transcriptionProviderName: transcriptionManager.currentMode.transcriptionProvider.displayName,
            powerModeId: aiService.selectedMode.id.uuidString,
            sourceTag: sourceTag
        )
        transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue

        modelContext.insert(transcription)
        applyPendingTags(to: transcription, modelContext: modelContext)

        do {
            try modelContext.save()
        } catch {
            logger.logError("📱 Failed to save the rescued recording: \(error.localizedDescription)")
            return nil
        }

        logger.logInfo("📱 Saved a failed-transcription note for \(audioURL.lastPathComponent) so the audio stays reachable")
        return transcription
    }

    /// Applies the tags selected during recording to the saved transcription and clears the buffer.
    ///
    /// Skips tag IDs already assigned (relevant for the append-to-note path, where the
    /// target transcription may already carry assignments). Called from every save path so
    /// in-recording tag selections survive regardless of how the recording is finalized.
    private func applyPendingTags(to transcription: Transcription, modelContext: ModelContext) {
        guard !pendingTagIds.isEmpty else { return }

        let alreadyAssigned = Set((transcription.tagAssignments ?? []).map(\.tagId))
        for tagId in pendingTagIds where !alreadyAssigned.contains(tagId) {
            modelContext.insert(TranscriptionTagAssignment(tagId: tagId, transcription: transcription))
        }
        pendingTagIds.removeAll()
    }

    private func appendTranscribedText(
        _ transcribedText: String,
        to transcriptionID: UUID,
        audioURL: URL,
        modelContext: ModelContext,
        audioDuration: Double,
        transcriptionDuration: TimeInterval?,
        sourceTag: String?
    ) throws -> Transcription {
        let descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.id == transcriptionID }
        )

        if let transcription = try modelContext.fetch(descriptor).first {
            transcription.appendToOriginalText(transcribedText)

            for variation in transcription.variations ?? [] {
                modelContext.delete(variation)
            }
            transcription.variations = []
            transcription.enhancedText = nil
            applyPendingTags(to: transcription, modelContext: modelContext)
            try modelContext.save()

            let transcriptionEntity = transcription.entity
            Task {
                await self.appState?.updateTranscriptionEntityInSpotlight(transcriptionEntity)
            }

            Task { await RAGIndexingService.shared.indexTranscription(transcription) }
            try? audioFileService.remove(at: audioURL)
            return transcription
        }

        logger.logWarning("📱 Append target note was not found, saving as a new note instead")
        return try saveNewTranscription(
            transcribedText: transcribedText,
            enhancedText: nil,
            promptName: nil,
            enhancementDur: nil,
            audioURL: audioURL,
            audioDuration: audioDuration,
            transcriptionDuration: transcriptionDuration,
            modelContext: modelContext,
            sourceTag: sourceTag
        )
    }

    private func scheduleAutomaticReminderExtractionIfNeeded(
        for transcription: Transcription,
        modelContext: ModelContext
    ) {
        guard UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.isAutoReminderExtractionEnabled) else {
            return
        }

        let extractionMode = aiService.selectedMode
        // Reminder extraction needs the full AIService (provider config + auth),
        // a wider surface than AIProcessingService - route it through the concrete
        // service on appState rather than the narrowed seam.
        guard let appState else { return }
        let extractionService = ReminderExtractionService(aiService: appState.aiService)
        guard extractionService.canExtractReminders(using: extractionMode) else {
            logger.logDebug("Reminder extraction - Auto extraction skipped because no extractor is available for mode \(extractionMode.name)")
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let result = try await extractionService.extractAndPersist(
                    for: transcription,
                    modelContext: modelContext,
                    mode: extractionMode
                )
                logger.logNotice("Reminder extraction - Auto extracted \(result.reminders.count) reminder(s) and \(result.events.count) event(s) for note \(transcription.id.uuidString)")
            } catch {
                logger.logWarning("Reminder extraction - Auto extraction failed for note \(transcription.id.uuidString): \(error.localizedDescription)")
            }
        }
    }

    func resetValues() {
        audioPower = 0
        transcriptionProgress = nil
        appGroupBridge.updateAudioLevel(0)

        _ = audioRecordingService.stopRecording()

        audioPlayer?.stop()
        audioPlayer = nil

        animationTimer?.invalidate()
        animationTimer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            resetValues()
            recordingState = .idle
        }
    }

    // MARK: - Keyboard Recording Handlers

    private func setupKeyboardRecordingHandlers() {
        // Handle start recording request from keyboard
        appGroupBridge.onStartRecordingRequested = { [weak self] in
            guard let self = self else { return }

            // A parked voice instruction turns this recording into a rewrite
            // instruction rather than a note. Consume it either way: leaving it
            // behind would make the *next* ordinary dictation an instruction.
            let voiceInstruction = self.appGroupBridge.getAndConsumePendingVoiceInstruction()

            // Only start if prewarm session is active and not already recording
            guard self.prewarmManager.isSessionActive && self.recordingState != .recording else {
                // The keyboard is blocked awaiting a result it will never get,
                // so say so rather than letting it hang until session expiry.
                if voiceInstruction != nil {
                    self.isAwaitingVoiceInstructionResult = true
                    self.failPendingVoiceInstruction("Could not start recording. Open VivaDicta and try again.")
                }
                return
            }

            self.logger.logInfo("📱 Starting recording from keyboard request")

            // Reload the selected VivaMode from extension before starting
            self.aiService.reloadSelectedModeFromExtension()
            // Update TranscriptionManager with the reloaded mode
            self.transcriptionManager.setCurrentMode(self.aiService.selectedMode)

            let destination: RecordingDestination = voiceInstruction
                .map { .voiceInstruction(targetText: $0.targetText, modeName: $0.modeName) } ?? .newNote
            self.isAwaitingVoiceInstructionResult = voiceInstruction != nil
            self.startCaptureAudio(destination: destination, sourceTag: SourceTag.keyboard)
        }

        // Handle stop recording request from keyboard
        appGroupBridge.onStopRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Stopping recording from keyboard request")

                // Reload the selected VivaMode from extension before transcription
                self.aiService.reloadSelectedModeFromExtension()
                // Update TranscriptionManager with the reloaded mode
                self.transcriptionManager.setCurrentMode(self.aiService.selectedMode)

                self.stopCaptureAudio(modelContext: modelContext)
            }
        }

        // Handle cancel recording request from keyboard
        appGroupBridge.onCancelRecordingRequested = { [weak self] in
            guard let self = self else { return }

            switch self.recordingState {
            case .recording:
                self.logger.logInfo("📱 Canceling recording from keyboard request")
                self.cancelTranscribe()
            case .transcribing, .enhancing:
                self.logger.logInfo("📱 Canceling processing from keyboard request")
                // Use cancelProcessing() for smart cancel behavior:
                // - Transcribing: cancels everything, no data saved
                // - Enhancing: saves transcription without enhancement
                self.cancelProcessing()
            default:
                break
            }
        }

        // Handle pause recording request from keyboard
        appGroupBridge.onPauseRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Pausing recording from keyboard request")
                // TODO: Implement pause functionality if needed
            }
        }

        // Handle resume recording request from keyboard
        appGroupBridge.onResumeRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Resuming recording from keyboard request")
                // TODO: Implement resume functionality if needed
            }
        }

        // Handle start recording request from Control Center
        appGroupBridge.onStartRecordingFromControl = { [weak self] in
            guard let self = self else { return }

            self.logger.logInfo("📱 Starting recording from Control Center request")

            // Start recording
            self.appState?.shouldStartRecording = true
            self.logger.logInfo("🎙️ Starting recording from Control Center")
        }

        // Handle VivaMode change from keyboard extension
        appGroupBridge.onVivaModeChanged = { [weak self] in
            guard let self = self else { return }

            self.logger.logInfo("📱 VivaMode changed from keyboard extension")
            self.aiService.reloadSelectedModeFromExtension()
        }

        // Handle text processing request from keyboard (rewrite feature)
        appGroupBridge.onTextProcessingRequested = { [weak self] in
            guard let self = self else { return }
            self.handleKeyboardTextProcessingRequest()
        }
    }

    // MARK: - Keyboard Text Processing

    private func handleKeyboardTextProcessingRequest() {
        guard let pending = appGroupBridge.getAndConsumePendingTextProcessing() else {
            logger.logError("📝 Text processing requested but no pending data found")
            appGroupBridge.shareTextProcessingError("No text to process")
            return
        }

        // Liveness gate: a nil weak appState means the app context is gone, so
        // there is nothing to process for. The bound value is intentionally unused -
        // the AI work routes through the injected aiService.
        guard appState != nil else {
            appGroupBridge.shareTextProcessingError("App not ready")
            return
        }

        logger.logInfo("📝 Processing text from keyboard with mode: \(pending.modeName), preset: \(pending.presetId ?? "nil"), text length: \(pending.text.count)")

        // Extend session while processing (same pattern as recording flow)
        let timeoutSeconds = prewarmManager.audioSessionTimeout
        appGroupBridge.refreshKeyboardSessionExpiry(timeoutSeconds: timeoutSeconds)

        // Temporarily switch to the requested mode, then restore.
        // Uses the injected `aiService` (== appState.aiService) so the AI surface
        // is reached through one mockable seam.
        let previousMode = aiService.selectedMode
        let requestedMode = aiService.getMode(name: pending.modeName)
        aiService.selectedMode = requestedMode

        Task {
            defer { aiService.selectedMode = previousMode }
            do {
                let result: String
                // If a preset ID is specified, use generateVariation with that preset
                if let presetId = pending.presetId,
                   let preset = aiService.presetManager?.preset(for: presetId) {
                    let (text, _) = try await aiService.generateVariation(text: pending.text, preset: preset)
                    result = text
                } else {
                    let (text, _, _) = try await aiService.enhance(pending.text)
                    result = text
                }
                logger.logInfo("📝 Text processing completed, result length: \(result.count)")
                if result.isEmpty {
                    logger.logError("📝 Text processing returned empty result")
                    appGroupBridge.shareTextProcessingError("AI returned empty result")
                } else {
                    appGroupBridge.shareTextProcessingResult(result)
                }
            } catch {
                logger.logError("📝 Text processing failed: \(error.localizedDescription)")
                appGroupBridge.shareTextProcessingError(error.localizedDescription)
            }
        }
    }
}
