//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.03
//

import SwiftUI
import Foundation
import AVFoundation
import SwiftData
import os

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case error(RecordError)
}

enum RecordError: LocalizedError, Equatable {
    case avInitError
    case userDenied
    case recordError
    case transcribe
    case other
    case debugError

    var errorDescription: String? {
        switch self {
        case .avInitError:
            "Audio initialization failed"
        case .userDenied:
            "Microphone access denied"
        case .recordError:
            "Recording failed"
        case .transcribe:
            "Transcription failed"
        case .other:
            "Unexpected error"
        case .debugError:
            "DEBUG ERROR"
        }
    }

    var failureReason: String {
        switch self {
        case .avInitError:
            return "Failed to initialize audio recording system. Please restart the app and try again."
        case .userDenied:
            return "Microphone access is required for recording. Please go to Settings > Privacy & Security > Microphone and enable access for VivaDicta."
        case .recordError:
            return "Failed to record audio. Check that no other app is using the microphone and try again."
        case .transcribe:
            return "Failed to transcribe the recorded audio. Please check your transcription settings and try again."
        case .other:
            return "An unexpected error occurred. Please restart the app and try again."
        case .debugError:
            return "DEBUG ERROR"
        }
    }
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
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "RecordViewModel")

    var animationTimer: Timer?
    var recordingHeartbeatTimer: Timer?

    weak var appState: AppState?
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

    var availableModes: [FlowMode] {
        appState?.aiService.modes ?? []
    }

    // TODO: Add auto stop feature later
//    var recordingTimer: Timer?
//    var prevAudioPower: Double?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupDarwinNotificationObservers()
    }

    // Note: No deinit cleanup needed for Darwin observers
    // The AppGroupCoordinator will properly handle duplicate registrations by
    // removing old observers before adding new ones (see AppGroupCoordinator.addObserver)
    
    var transcribingSpeechTask: Task<Void, Never>?
    
    var captureURL: URL {
        FileManager.appDirectory(for: .audio).appendingPathComponent("recording.m4a")
    }
    
    var recordingState: RecordingState = .idle {
        didSet {
            logger.info("📱 Recording state changed: \(String(describing: self.recordingState))")
            // Save recording state to shared UserDefaults for keyboard extension
            let isRecording = (recordingState == .recording)
            UserDefaultsStorage.shared.set(isRecording, forKey: "isRecording")
            UserDefaultsStorage.shared.synchronize()
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
                logger.info("📱 Already recording, ignoring duplicate start request")
                return
            }

            // Check if prewarm session is active (keyboard recording)
            if prewarmManager.isSessionActive {
                logger.info("🎙️ Using prewarm session for recording")

                resetValues()
                recordingState = .recording
                startRecordingHeartbeat()  // Start heartbeat when recording starts

                do {
                    // Use prewarm manager's parallel real recorder
                    // This will start recording alongside the dummy recorder
                    try prewarmManager.startRealCapture(to: captureURL)

                    // Set audioRecorder reference to prewarm's real recorder for metering
                    audioRecorder = prewarmManager.activeRealRecorder

                    // Start metering timer for visualization
                    animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [weak self]_ in
                        Task { @MainActor in
                            guard self?.audioRecorder != nil else { return }
                            self?.audioRecorder.updateMeters()
                            if let audioRecorder = self?.audioRecorder {
                                let power = min(1, max(0, 1 - abs(Double(audioRecorder.averagePower(forChannel: 0)) / 50) ))
                                self?.audioPower = power
                            }
                        }
                    })

                } catch {
                    resetValues()
                    recordingState = .error(.recordError)
                    return
                }

            } else {
                // Normal recording flow (not from keyboard)
                logger.info("🎙️ Using normal recording flow")

                
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
                startRecordingHeartbeat()  // Start heartbeat when recording starts

                do {
                    let settings: [String : Any] = [
                        AVFormatIDKey: Int(kAudioFormatLinearPCM),
                        AVSampleRateKey: 16000.0,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
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
        // Stop real recorder if in prewarm mode (dummy continues running)
        if prewarmManager.isSessionActive {
            logger.info("🎙️ Stopping real capture in prewarm mode (dummy continues)")
            prewarmManager.stopRealCapture()

            // In prewarm mode, we need a small delay to ensure file is flushed to disk
            // before trying to move it
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

                resetValues()
                stopRecordingHeartbeat()  // Stop heartbeat when recording stops

                let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).m4a")
                do {
                    try FileManager.default.moveItem(at: captureURL, to: finalURL)
                    transcribingSpeechTask = transcribeSpeechTask(recordURL: finalURL, modelContext: modelContext)
                } catch {
                    logger.error("📱 Failed to move audio file: \(error.localizedDescription)")
                }
            }
        } else {
            // Normal mode
            resetValues()
            stopRecordingHeartbeat()  // Stop heartbeat when recording stops
            

            let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).m4a")
            do {
                try FileManager.default.moveItem(at: captureURL, to: finalURL)
                transcribingSpeechTask = transcribeSpeechTask(recordURL: finalURL, modelContext: modelContext)
            } catch {
                logger.error("📱 Failed to move audio file: \(error.localizedDescription)")
            }
        }
    }
    
    func transcribeSpeechTask(recordURL: URL, modelContext: ModelContext) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                self.recordingState = .transcribing

                // Notify keyboard that transcription has started
                AppGroupCoordinator.shared.notifyTranscriptionStarted()

                let transcriptionStart = Date()
                let transcribedText = try await transcriptionManager.transcribe(audioURL: recordURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
                
                let audioAsset = AVURLAsset(url: recordURL)
                let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                // Notify keyboard that transcription has ended
                AppGroupCoordinator.shared.notifyTranscriptionEnded()
                
                var enhancedText: String? = nil
                var promptName: String? = nil
                var enhancementDur: TimeInterval? = nil
                
                // Check if AI Enhancement is properly configured
                if aiService.isProperlyConfigured() {
                    // Notify keyboard that AI enhancement has started
                    AppGroupCoordinator.shared.notifyAIEnhancementStarted()

                    do {
                        let (enhanced, enhancementDuration, prompt) = try await aiService.enhance(transcribedText)
                        
                        // Notify keyboard that AI enhancement has ended
                        AppGroupCoordinator.shared.notifyAIEnhancementEnded()
                        
                        enhancedText = enhanced
                        promptName = prompt
                        enhancementDur = enhancementDuration
                        
                    } catch {
                        // Enhancement failed
                        logger.warning("📱 AI enhancement failed: \(error.localizedDescription)")
                        try Task.checkCancellation()
                        self.recordingState = .idle
                    }
                }
                
                // Create and save transcription to SwiftData
                let transcription = Transcription(
                    text: transcribedText,
                    enhancedText: enhancedText,
                    audioDuration: audioDuration,
                    audioFileName: recordURL.lastPathComponent,
                    transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                    aiEnhancementModelName: enhancedText != nil ? aiService.selectedMode.aiModel : nil,
                    promptName: promptName,
                    transcriptionDuration: transcriptionDuration,
                    enhancementDuration: enhancementDur
                )

                modelContext.insert(transcription)
                try modelContext.save()
                
                try Task.checkCancellation()
                self.recordingState = .idle
                
            } catch {
                if Task.isCancelled { return }
                recordingState = .error(.transcribe)
                resetValues()
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
                }
            }
        })
    }
    
    func cancelTranscribe() {
        transcribingSpeechTask?.cancel()
        transcribingSpeechTask = nil
        resetValues()
        stopRecordingHeartbeat()  // Stop heartbeat when canceling
        recordingState = .idle
    }
    
    func resetValues() {
        audioPower = 0
        
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

    // MARK: - Recording Heartbeat

    private func startRecordingHeartbeat() {
        // Guard against duplicate starts
        guard recordingHeartbeatTimer == nil else {
            logger.info("💙 Recording heartbeat timer already running, skipping duplicate start")
            return
        }

        // Send initial heartbeat
        updateRecordingHeartbeat()

        // Start new heartbeat timer
        recordingHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppGroupConfig.recordingHeartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingHeartbeat()
            }
        }

        logger.info("💙 Started recording heartbeat timer")
    }

    private func stopRecordingHeartbeat() {
        recordingHeartbeatTimer?.invalidate()
        recordingHeartbeatTimer = nil

        // Clear the heartbeat timestamp and recording flag to indicate recording has stopped
        UserDefaultsStorage.shared.set(0.0, forKey: AppGroupConfig.recordingHeartbeatKey)
        UserDefaultsStorage.shared.set(false, forKey: "isRecording")  // Explicitly clear the recording flag
        UserDefaultsStorage.shared.synchronize()

        logger.info("💙 Stopped recording heartbeat timer and cleared recording flag")
    }

    private func updateRecordingHeartbeat() {
        let currentTime = Date().timeIntervalSince1970
        UserDefaultsStorage.shared.set(currentTime, forKey: AppGroupConfig.recordingHeartbeatKey)
        UserDefaultsStorage.shared.synchronize()

        logger.debug("💙 Updated recording heartbeat: \(String(format: "%.1f", currentTime))")
    }

    // MARK: - Darwin Notification Handling

    private func setupDarwinNotificationObservers() {
        // Observe start recording request from keyboard
        AppGroupCoordinator.shared.observeStartRecording { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("📱 Received Darwin notification: Start Recording from keyboard")

                // Check if already recording
                guard self.recordingState != .recording else {
                    self.logger.info("📱 Already recording, ignoring start request")
                    return
                }

                // Start recording
                self.startCaptureAudio()

                // Notify keyboard that recording has started
                AppGroupCoordinator.shared.notifyRecordingStarted()
            }
        }

        // Observe stop recording request from keyboard
        AppGroupCoordinator.shared.observeStopRecording { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("📱 Received Darwin notification: Stop Recording from keyboard")

                // Check if actually recording
                guard self.recordingState == .recording else {
                    self.logger.info("📱 Not recording, ignoring stop request")
                    return
                }

                // Stop recording and handle transcription for keyboard
                self.stopCaptureAudioForKeyboard()
            }
        }

        // Observe cancel recording request from keyboard (no transcription)
        AppGroupCoordinator.shared.observeCancelRecording { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("📱 Received Darwin notification: Cancel Recording from keyboard")

                // Check if actually recording
                guard self.recordingState == .recording else {
                    self.logger.info("📱 Not recording, ignoring cancel request")
                    return
                }

                // Cancel recording without transcription
                self.cancelCaptureAudioForKeyboard()
            }
        }
    }

    private func cancelCaptureAudioForKeyboard() {
        logger.info("📱 Canceling recording from keyboard - no transcription")

        // Stop recording without transcription
        resetValues()
        stopRecordingHeartbeat()  // Stop heartbeat when keyboard cancels recording

        // Notify keyboard that recording has stopped
        AppGroupCoordinator.shared.notifyRecordingStopped()

        // Clear recording state to prevent transcription
        recordingState = .idle
    }

    private func stopCaptureAudioForKeyboard() {
        // Stop real recorder if in prewarm mode (dummy continues running)
        if prewarmManager.isSessionActive {
            logger.info("🎙️ Stopping real capture in prewarm mode for keyboard (dummy continues)")
            prewarmManager.stopRealCapture()

            // In prewarm mode, we need a small delay to ensure file is flushed to disk
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay

                resetValues()
                stopRecordingHeartbeat()  // Stop heartbeat when keyboard stops recording

                // Notify keyboard that recording has stopped
                AppGroupCoordinator.shared.notifyRecordingStopped()

                // Don't schedule session deactivation - prewarm session continues

                // Save the audio file
                let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).m4a")
                do {
                    try FileManager.default.moveItem(at: captureURL, to: finalURL)

                    // Start transcription task that will save to both UserDefaults and SwiftData
                    transcribingSpeechTask = transcribeSpeechTaskForKeyboard(recordURL: finalURL)
                } catch {
                    logger.error("📱 Failed to move audio file: \(error.localizedDescription)")
                    recordingState = .error(.recordError)
                }
            }
        } else {
            // TODO: - probably safe to delete - if there's no prewarm session, we can't catch darwin notification
            // Normal mode (not using prewarm)
            resetValues()
            stopRecordingHeartbeat()  // Stop heartbeat when keyboard stops recording

            // Notify keyboard that recording has stopped
            AppGroupCoordinator.shared.notifyRecordingStopped()

            // Save the audio file
            let finalURL = FileManager.appDirectory(for: .audio).appendingPathComponent("\(UUID().uuidString).m4a")
            do {
                try FileManager.default.moveItem(at: captureURL, to: finalURL)

                // Start transcription task that will save to both UserDefaults and SwiftData
                
                // TODO: Disabling transcription and Setting Debug Error, this path should never happen
//                transcribingSpeechTask = transcribeSpeechTaskForKeyboard(recordURL: finalURL)
                recordingState = .error(.debugError)
            } catch {
                logger.error("📱 Failed to move audio file: \(error.localizedDescription)")
                recordingState = .error(.recordError)
            }
        }
    }

    private func transcribeSpeechTaskForKeyboard(recordURL: URL) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                self.recordingState = .transcribing

                // Notify keyboard that transcription has started
                AppGroupCoordinator.shared.notifyTranscriptionStarted()

                let transcriptionStart = Date()
                let transcribedText = try await transcriptionManager.transcribe(audioURL: recordURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

                // Get audio duration
                let audioAsset = AVURLAsset(url: recordURL)
                let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                // Notify keyboard that transcription has ended
                AppGroupCoordinator.shared.notifyTranscriptionEnded()
                
                // Load the selected flow mode from shared UserDefaults (set by keyboard)
                if let selectedModeName = UserDefaultsStorage.shared.string(forKey: AppGroupConfig.selectedAIModeKey) {
                    logger.info("📱 Loading flow mode from keyboard: \(selectedModeName)")
                    // Update the AI service's selected mode to match what was selected in keyboard
                    aiService.selectedModeName = selectedModeName
                }
                
                // Check if AI Enhancement is configured
                var enhancedText: String? = nil
                var promptName: String? = nil
                var enhancementDur: TimeInterval? = nil

                if aiService.isProperlyConfigured() {
                    // Notify keyboard that AI enhancement has started
                    AppGroupCoordinator.shared.notifyAIEnhancementStarted()

                    do {
                        let (enhanced, enhancementDuration, prompt) = try await aiService.enhance(transcribedText)
                        enhancedText = enhanced
                        promptName = prompt
                        enhancementDur = enhancementDuration

                        // Notify keyboard that AI enhancement has ended
                        AppGroupCoordinator.shared.notifyAIEnhancementEnded()
                    } catch {
                        logger.warning("📱 AI enhancement failed: \(error.localizedDescription)")
                        // Notify keyboard that AI enhancement has ended (even on failure)
                        AppGroupCoordinator.shared.notifyAIEnhancementEnded()
                    }
                }

                // Save the ENHANCED text (if available) or original text to shared UserDefaults for keyboard
                let textToInsert = enhancedText ?? transcribedText
                UserDefaultsStorage.shared.set(textToInsert, forKey: "lastTranscription")
                UserDefaultsStorage.shared.synchronize()

                // Also save to SwiftData using Persistence.container
                let context = ModelContext(Persistence.container)

                // Create and save transcription to SwiftData
                let transcription = Transcription(
                    text: transcribedText,
                    enhancedText: enhancedText,
                    audioDuration: audioDuration,
                    audioFileName: recordURL.lastPathComponent,
                    transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                    aiEnhancementModelName: enhancedText != nil ? aiService.selectedMode.aiModel : nil,
                    promptName: promptName,
                    transcriptionDuration: transcriptionDuration,
                    enhancementDuration: enhancementDur
                )

                context.insert(transcription)
                try context.save()
                
                // Notify keyboard that transcription is ready
                AppGroupCoordinator.shared.notifyTranscriptionReady()

                self.recordingState = .idle

                let savedTextType = enhancedText != nil ? "enhanced" : "original"
                logger.info("📱 Transcription (\(savedTextType)) saved to UserDefaults and SwiftData, notification sent to keyboard")
            } catch {
                self.recordingState = .error(.transcribe)

                // Notify keyboard about error
                AppGroupCoordinator.shared.notifyRecordingError()

                logger.error("📱 Transcription failed: \(error.localizedDescription)")
            }
        }
    }
}
