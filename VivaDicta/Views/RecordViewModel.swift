//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import Foundation
import AVFoundation
@preconcurrency import AVFAudio
import SwiftData
import os

// Data structure to hold pending transcription when enhancement is in progress
private struct PendingTranscriptionData {
    let text: String
    let audioDuration: Double
    let audioFileName: String
    let transcriptionModelName: String?
    let transcriptionProviderName: String?
    let transcriptionDuration: TimeInterval
    let modelContext: ModelContext
}

@Observable @MainActor
class RecordViewModel: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!
    
//    private let sessionManager = AudioSessionManager.shared
#if !os(macOS)
    var recordingSession = AVAudioSession.sharedInstance()
#endif
    
    private let prewarmManager = AudioPrewarmManager.shared
    private let logger = Logger(category: .recordViewModel)

    var animationTimer: Timer?

    weak var appState: AppState?
    var modelContext: ModelContext
    
    public var transcriptionManager: TranscriptionManager {
        appState?.transcriptionManager ?? TranscriptionManager()
    }
    public var aiService: AIService {
        appState?.aiService ?? AIService()
    }

    var selectedModeName: String {
        get { appState?.aiService.selectedModeName ?? "" }
        set { appState?.aiService.selectedModeName = newValue }
    }

    var availableModes: [VivaMode] {
        appState?.aiService.modes ?? []
    }

    // TODO: Add auto stop feature later
//    var recordingTimer: Timer?
//    var prevAudioPower: Double?

    init(appState: AppState, modelContainer: ModelContainer) {
        self.appState = appState
        self.modelContext = ModelContext(modelContainer)
        super.init()
        setupKeyboardRecordingHandlers()
    }

    // Note: No deinit cleanup needed for Darwin observers
    // The AppGroupCoordinator will properly handle duplicate registrations by
    // removing old observers before adding new ones (see AppGroupCoordinator.addObserver)
    
    var transcribingSpeechTask: Task<Void, Never>?

    // Pending transcription data for saving when enhancement is cancelled
    private var pendingTranscription: PendingTranscriptionData?

    var captureURL: URL {
        FileManager.appDirectory(for: .audio).appendingPathComponent("recording.wav")
    }
    
    var recordingState: RecordingState = .idle {
        didSet {
            logger.logInfo("📱 Recording state changed: \(String(describing: self.recordingState))")
            // Recording state is shared with keyboard extension via AppGroupCoordinator.shared.updateRecordingState()
            // which is called in startCaptureAudio(), stopCaptureAudio(), and cancelTranscribe()
        }
    }
    
    var isShowingAlert = false
    var recordError: RecordError = .other
    
    var audioPower = 0.0
    var siriWaveFormOpacity: CGFloat {
        switch recordingState {
        case .recording: return 1
        default: return 0
        }
    }
    
    private func setupAudioSession() async throws -> Bool {
#if !os(macOS)
        do {
#if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            try recordingSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
#endif
            try recordingSession.setActive(true)
            
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        } catch {
            throw RecordError.other
        }
#else
        return true
#endif
    }
    
    
    
    func startCaptureAudio() {
        Task { @MainActor in
            // Guard against duplicate starts
            guard recordingState != .recording else {
                logger.logInfo("📱 Already recording, ignoring duplicate start request")
                return
            }

            // Prewarm Apple Foundation Model if needed - user will need AI enhancement
            // within seconds after recording completes
            appState?.aiService.prewarmFoundationModelIfNeeded()

            // Check if prewarm session is active (keyboard recording)
            if prewarmManager.isSessionActive {
                logger.logInfo("🎙️ Using prewarm session for recording")

                resetValues()
                recordingState = .recording
                HapticManager.mediumImpact()

                // Notify keyboard that recording has started
                AppGroupCoordinator.shared.updateRecordingState(true)

                do {
                    // Use prewarm manager's AVAudioEngine for recording
                    try prewarmManager.startRealCapture(to: captureURL)

                    // Update audio levels from prewarmManager for visualization
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
                        Task { @MainActor in
                            guard let self = self else { return }
                            let level = Double(self.prewarmManager.currentAudioLevel)
                            self.audioPower = level
                            AppGroupCoordinator.shared.updateAudioLevel(level)
                        }
                    })

                } catch {
                    resetValues()
                    recordingState = .error(.recordError)
                    return
                }

            } else {
                // Normal recording flow (not from keyboard)
                logger.logInfo("🎙️ Using normal recording flow")

                
                do {
                    let hasPermission = try await setupAudioSession()
                    
                    if !hasPermission {
                        recordError = .userDenied
                        isShowingAlert = true
                        return
                    }
                } catch {
                    recordingState = .error(.other)
                    return
                }

                resetValues()
                recordingState = .recording
                HapticManager.mediumImpact()

                // Notify keyboard that recording has started (even in normal mode)
                AppGroupCoordinator.shared.updateRecordingState(true)

                do {
                    let settings: [String : Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: 16_000.0,
                        AVNumberOfChannelsKey: 1,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsFloatKey: false
                    ]
                    
                    audioRecorder = try AVAudioRecorder(
                        url: captureURL,
                        settings: settings)
                    audioRecorder.isMeteringEnabled = true
                    audioRecorder.delegate = self
                    audioRecorder.record()

                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
                        Task { @MainActor in
                            guard self?.audioRecorder != nil else { return }
                            self?.audioRecorder.updateMeters()
                            if let audioRecorder = self?.audioRecorder {
                                let power = min(1, max(0, 1 - abs(Double(audioRecorder.averagePower(forChannel: 0)) / 50) ))
                                self?.audioPower = power
                                AppGroupCoordinator.shared.updateAudioLevel(power)
                            }

                        }
                    })
            
            // TODO: Add auto stop feature later
//            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true, block: { [unowned self]_ in
//                guard self.audioRecorder != nil else { return }
//                self.audioRecorder.updateMeters()
//                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
//                if self.prevAudioPower == nil {
//                    self.prevAudioPower = power
//                    return
//                }
//                if let prevAudioPower = self.prevAudioPower, prevAudioPower < 0.25 && power < 0.175 {
//                    self.stopCaptureAudio()
//                    return
//                }
//                self.prevAudioPower = power
//            })

                } catch {
                    resetValues()
                    recordingState = .error(.recordError)
                }
            }
        }
    }
    
    func stopCaptureAudio(modelContext: ModelContext) {
        HapticManager.mediumImpact()

        // Stop real recorder if in prewarm mode (dummy continues running)
        if prewarmManager.isSessionActive {
            logger.logInfo("🎙️ Stopping real capture in prewarm mode (dummy continues)")
            prewarmManager.stopRealCapture()

            // In prewarm mode, we need a small delay to ensure file is flushed to disk
            // before trying to move it
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

                resetValues()

                // Notify keyboard that recording has stopped
                AppGroupCoordinator.shared.updateRecordingState(false)

                let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).wav")
                do {
                    try FileManager.default.moveItem(at: captureURL, to: finalURL)
                    transcribingSpeechTask = transcribeSpeechTask(recordURL: finalURL, modelContext: modelContext)
                } catch {
                    logger.logError("📱 Failed to move audio file: \(error.localizedDescription)")
                }
            }
        } else {
            // Normal mode
            resetValues()

            // Notify keyboard that recording has stopped
            AppGroupCoordinator.shared.updateRecordingState(false)

            let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).wav")
            do {
                try FileManager.default.moveItem(at: captureURL, to: finalURL)
                transcribingSpeechTask = transcribeSpeechTask(recordURL: finalURL, modelContext: modelContext)
            } catch {
                logger.logError("📱 Failed to move audio file: \(error.localizedDescription)")
            }
        }
    }
    
    /// Downsample audio file to 16kHz mono for optimal transcription
    private func downsampleTo16kHzMono(inputURL: URL, outputURL: URL) async throws {
        // 1) Open source file
        let inFile = try AVAudioFile(forReading: inputURL)
        let inFmt = inFile.processingFormat

        // 2) Target format: 16kHz, mono, PCM Int16
        guard let outFmt = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecordError.other
        }

        // 3) Create converter with quality settings
        guard let converter = AVAudioConverter(from: inFmt, to: outFmt) else {
            throw RecordError.other
        }
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue

        // 4) Read entire input file
        let frameCount = AVAudioFrameCount(inFile.length)
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inFmt, frameCapacity: frameCount) else {
            throw RecordError.other
        }
        try inFile.read(into: inputBuffer)

        // 5) Calculate output buffer size
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * (16000.0 / inFmt.sampleRate))
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: outputFrameCount) else {
            throw RecordError.other
        }

        // 6) Convert
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let error = error {
            throw error
        }

        // 7) Write output file
        let outFile = try AVAudioFile(forWriting: outputURL, settings: outFmt.settings, commonFormat: outFmt.commonFormat, interleaved: false)
        try outFile.write(from: outputBuffer)
    }

    func transcribeSpeechTask(recordURL: URL, modelContext: ModelContext) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                self.recordingState = .transcribing

                // Notify keyboard that transcription has started
                AppGroupCoordinator.shared.updateTranscriptionStatus(.transcribing)

                // Check if file needs downsampling (keyboard recordings are 48kHz)
                var audioURLToTranscribe = recordURL

                // Detect sample rate
                let tempFile = try AVAudioFile(forReading: recordURL)
                let sampleRate = tempFile.processingFormat.sampleRate

                if sampleRate > 16000 {
                    logger.logInfo("🎙️ Detected high sample rate (\(Int(sampleRate))Hz), downsampling to 16kHz")
                    // Use .wav extension for cross-platform PCM support
                    let downsampledURL = recordURL.deletingPathExtension().appendingPathExtension("16k.wav")

                    do {
                        try await downsampleTo16kHzMono(inputURL: recordURL, outputURL: downsampledURL)

                        // Verify the output file was created and has content
                        let attributes = try FileManager.default.attributesOfItem(atPath: downsampledURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0

                        if fileSize > 1000 {  // At least 1KB
                            // Delete original high-rate file to save space
                            try? FileManager.default.removeItem(at: recordURL)

                            // Use downsampled file for transcription
                            audioURLToTranscribe = downsampledURL
                            logger.logInfo("🎙️ Downsampling complete, file size: \(fileSize) bytes, saved ~\(Int((1.0 - 16000.0/sampleRate) * 100))% space")
                        } else {
                            logger.logWarning("🎙️ Downsampled file too small (\(fileSize) bytes), using original")
                            try? FileManager.default.removeItem(at: downsampledURL)
                        }
                    } catch {
                        logger.logWarning("🎙️ Downsampling failed, using original file: \(error.localizedDescription)")
                        // Continue with original file if downsampling fails
                    }
                }

                // Check for cancellation before starting transcription
                try Task.checkCancellation()

                let transcriptionStart = Date()
                let transcribedText = try await transcriptionManager.transcribe(audioURL: audioURLToTranscribe)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                // Check for cancellation after transcription
                try Task.checkCancellation()

                // Validate transcription has meaningful content (not empty, whitespace-only, or punctuation-only)
                guard TranscriptionOutputFilter.hasMeaningfulContent(transcribedText) else {
                    logger.logInfo("📱 Transcription contains no meaningful content, skipping save")

                    // Clean up audio file
                    try? FileManager.default.removeItem(at: audioURLToTranscribe)

                    // Reset state
                    resetValues()
                    recordingState = .idle
                    AppGroupCoordinator.shared.updateRecordingState(false)
                    AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
                    return
                }

                let audioAsset = AVURLAsset(url: audioURLToTranscribe)
                let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                // Notify keyboard that transcription has ended
//                AppGroupCoordinator.shared.notifyTranscriptionEnded()
                
                var enhancedText: String? = nil
                var promptName: String? = nil
                var enhancementDur: TimeInterval? = nil
                
                // Check if AI Enhancement is properly configured
                if aiService.isProperlyConfigured() {
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
                        modelContext: modelContext
                    )

                    // Update state to show enhancing animation
                    self.recordingState = .enhancing
                    HapticManager.lightImpact()

                    // Notify keyboard that AI enhancement has started
                    AppGroupCoordinator.shared.updateTranscriptionStatus(.enhancing)

                    do {
                        let (enhanced, enhancementDuration, prompt) = try await aiService.enhance(transcribedText)

                        enhancedText = enhanced
                        promptName = prompt
                        enhancementDur = enhancementDuration

                        // Clear pending data after successful enhancement
                        self.pendingTranscription = nil

                    } catch let error as AppleFoundationModelError {
                        // Apple Foundation Model specific error
                        logger.logWarning("📱 Apple Foundation Model error: \(error.localizedDescription)")
                        self.pendingTranscription = nil
                        try Task.checkCancellation()

                        // Show alert for guardrail violations so user knows why enhancement failed
                        if case .guardrailViolation = error {
                            self.recordError = .aiGuardrail
                            self.isShowingAlert = true
                        }
                    } catch {
                        // Other enhancement errors
                        logger.logWarning("📱 AI enhancement failed: \(error.localizedDescription)")
                        self.pendingTranscription = nil
                        try Task.checkCancellation()
                    }
                }
                
                // Create and save transcription to SwiftData
                let transcription = Transcription(
                    text: transcribedText,
                    enhancedText: enhancedText,
                    audioDuration: audioDuration,
                    audioFileName: audioURLToTranscribe.lastPathComponent,
                    transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                    transcriptionProviderName: transcriptionManager.currentMode.transcriptionProvider.displayName,
                    aiEnhancementModelName: enhancedText != nil ? aiService.selectedMode.aiModel : nil,
                    aiProviderName: enhancedText != nil ? aiService.selectedMode.aiProvider?.displayName : nil,
                    promptName: promptName,
                    transcriptionDuration: transcriptionDuration,
                    enhancementDuration: enhancementDur
                )

                modelContext.insert(transcription)
                try modelContext.save()

                // Index the new transcription in Spotlight
                await self.appState?.indexTranscriptionToSpotlight(transcription)

                // Create and donate user activity for Siri predictions
                if let appState = self.appState {
                    let activity = appState.userActivity(for: transcription)
                    activity.becomeCurrent()
                }

                // TODO: Generate tags after saving transcription
                // Task {
                //     if let tags = try? await aiService.generateTags(for: enhancedText ?? transcribedText) {
                //         transcription.tags = tags
                //         try? modelContext.save()
                //
                //         // Update the existing Spotlight item with new tags
                //         await appState.updateTranscriptionInSpotlight(transcription)
                //     }
                // }

                // Share transcribed text with keyboard (enhanced text if available, otherwise original)
                let textToShare = enhancedText ?? transcribedText
                AppGroupCoordinator.shared.shareTranscribedText(textToShare)

                try Task.checkCancellation()
                HapticManager.heartbeat()
                self.recordingState = .idle

                // Request app rating after successful transcription
                RateAppManager.requestReviewIfAppropriate()

                // Reschedule session timeout now that all processing is complete
                self.prewarmManager.rescheduleSessionTimeout()

            } catch {
                if Task.isCancelled { return }
                HapticManager.error()
                recordingState = .error(.transcribe)
                resetValues()

                // Notify keyboard of error
                AppGroupCoordinator.shared.updateTranscriptionError("Transcription failed: \(error.localizedDescription)")

                // Reschedule session timeout even on error
                self.prewarmManager.rescheduleSessionTimeout()
            }
        }
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
                    AppGroupCoordinator.shared.updateAudioLevel(power)
                }
            }
        })
    }
    
    func cancelTranscribe() {
        HapticManager.lightImpact()

        transcribingSpeechTask?.cancel()
        transcribingSpeechTask = nil
        pendingTranscription = nil

        // Stop real capture if still recording
        if prewarmManager.isSessionActive && prewarmManager.audioEngine?.isRunning == true {
            logger.logInfo("🎙️ Stopping real capture on cancel")
            prewarmManager.stopRealCapture()
        }

        // Clear any prewarmed Foundation Model session
        aiService.cancelFoundationModelPrewarm()

        resetValues()
        recordingState = .idle

        // Notify keyboard that recording was canceled
        AppGroupCoordinator.shared.updateRecordingState(false)
        AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)

        // Reschedule session timeout after cancellation
        prewarmManager.rescheduleSessionTimeout()
    }

    /// Cancels the current processing based on state:
    /// - Transcribing: cancels everything, doesn't save anything
    /// - Enhancing: cancels enhancement but saves the transcription without enhancement
    func cancelProcessing() {
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
                    AppGroupCoordinator.shared.updateRecordingState(false)
                    AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
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
                    enhancementDuration: nil
                )

                pending.modelContext.insert(transcription)
                do {
                    try pending.modelContext.save()
                    logger.logInfo("📱 Saved transcription without enhancement")

                    // Haptic feedback for successful save
                    HapticManager.heartbeat()

                    // Index to Spotlight
                    Task {
                        await self.appState?.indexTranscriptionToSpotlight(transcription)
                    }

                    // Share with keyboard
                    AppGroupCoordinator.shared.shareTranscribedText(pending.text)

                    // Request app rating after successful transcription
                    RateAppManager.requestReviewIfAppropriate()
                } catch {
                    logger.logError("📱 Failed to save transcription: \(error.localizedDescription)")
                }
            }

            resetValues()
            recordingState = .idle

            // Notify keyboard
            AppGroupCoordinator.shared.updateRecordingState(false)
            AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)

            // Reschedule session timeout after cancellation
            prewarmManager.rescheduleSessionTimeout()

        default:
            // For other states, just use regular cancel (which also reschedules timeout)
            cancelTranscribe()
        }
    }
    
    func resetValues() {
        audioPower = 0
        AppGroupCoordinator.shared.updateAudioLevel(0)

        audioRecorder?.stop()
        audioRecorder = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        // TODO: Add auto stop feature later
//        prevAudioPower = nil
//        recordingTimer?.invalidate()
//        recordingTimer = nil
        
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                resetValues()
                recordingState = .idle
            }
        }
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
        AppGroupCoordinator.shared.onStartRecordingRequested = { [weak self] in
            guard let self = self else { return }

            // Only start if prewarm session is active and not already recording
            if self.prewarmManager.isSessionActive && self.recordingState != .recording {
                self.logger.logInfo("📱 Starting recording from keyboard request")

                // Reload the selected VivaMode from extension before starting
                self.appState?.aiService.reloadSelectedModeFromExtension()
                // Update TranscriptionManager with the reloaded mode
                if let selectedMode = self.appState?.aiService.selectedMode {
                    self.appState?.transcriptionManager.setCurrentMode(selectedMode)
                }

                self.startCaptureAudio()
            }
        }

        // Handle stop recording request from keyboard
        AppGroupCoordinator.shared.onStopRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Stopping recording from keyboard request")

                // Reload the selected VivaMode from extension before transcription
                self.appState?.aiService.reloadSelectedModeFromExtension()
                // Update TranscriptionManager with the reloaded mode
                if let selectedMode = self.appState?.aiService.selectedMode {
                    self.appState?.transcriptionManager.setCurrentMode(selectedMode)
                }

                // Create a new ModelContext from Persistence container
//                let context = ModelContext(Persistence.container)
                self.stopCaptureAudio(modelContext: modelContext)
            }
        }

        // Handle cancel recording request from keyboard
        AppGroupCoordinator.shared.onCancelRecordingRequested = { [weak self] in
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
        AppGroupCoordinator.shared.onPauseRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Pausing recording from keyboard request")
                // TODO: Implement pause functionality if needed
            }
        }

        // Handle resume recording request from keyboard
        AppGroupCoordinator.shared.onResumeRecordingRequested = { [weak self] in
            guard let self = self else { return }

            if self.recordingState == .recording {
                self.logger.logInfo("📱 Resuming recording from keyboard request")
                // TODO: Implement resume functionality if needed
            }
        }

        // Handle start recording request from Control Center
        AppGroupCoordinator.shared.onStartRecordingFromControl = { [weak self] in
            guard let self = self else { return }

            self.logger.logInfo("📱 Starting recording from Control Center request")

            // Start recording
            self.appState?.shouldStartRecording = true
            self.logger.logInfo("🎙️ Starting recording from Control Center")
        }

        // Handle VivaMode change from keyboard extension
        AppGroupCoordinator.shared.onVivaModeChanged = { [weak self] in
            guard let self = self else { return }

            self.logger.logInfo("📱 VivaMode changed from keyboard extension")
            self.appState?.aiService.reloadSelectedModeFromExtension()
        }
    }
}
