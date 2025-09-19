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

enum RecordingState {
    case idle
    case recording
    case transcribing
    case error(RecordError)
}

enum RecordError: Error {
    case avInitError
    case userDenied
    case recordError
    case transcribe
    case other
}

@Observable @MainActor
class RecordViewModel: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    var audioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!
    #if !os(macOS)
    var recordingSession = AVAudioSession.sharedInstance()
    #endif
    
    var animationTimer: Timer?
    
//    var transcriptionService: TranscriptionService?
    private let transcriptionManager: TranscriptionManager
    private let aiService: AIService?

    // TODO: Add auto stop feature later
//    var recordingTimer: Timer?
//    var prevAudioPower: Double?

    init(transcriptionManager: TranscriptionManager, aiService: AIService? = nil) {
        self.transcriptionManager = transcriptionManager
        self.aiService = aiService
        super.init()
        setupAudioSession()
    }
    
    var transcribingSpeechTask: Task<Void, Never>?
    
    var captureURL: URL {
        URL.documentsDirectory.appendingPathComponent("recording.m4a")
    }
    
    var recordingState: RecordingState = .idle {
        didSet {
            print(recordingState)
        }
    }
    
    var audioPower = 0.0
    var siriWaveFormOpacity: CGFloat {
        switch recordingState {
        case .recording: return 1
        default: return 0
        }
    }
    
    private func setupAudioSession() {
        #if !os(macOS)
        do {
            #if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #endif
            try recordingSession.setActive(true)

            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                Task { @MainActor in
                    if !allowed {
                        self?.recordingState = .error(.userDenied)
                    }
                }
            }
        } catch {
            recordingState = .error(.other)
        }
        #endif
    }
    
    
    func startCaptureAudio() {
        resetValues()
        recordingState = .recording
        
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
            
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
                Task { @MainActor in
                    guard self.audioRecorder != nil else { return }
                    self.audioRecorder.updateMeters()
                    let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                    self.audioPower = power
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
    
    func stopCaptureAudio(modelContext: ModelContext) {
        resetValues()
        let finalURL = URL.documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        do {
            try FileManager.default.moveItem(at: captureURL, to: finalURL)
            transcribingSpeechTask = transcribeSpeechTask(recordURL: finalURL, modelContext: modelContext)
        } catch {
            print("file err")
        }
    }
    
    func transcribeSpeechTask(recordURL: URL, modelContext: ModelContext) -> Task<Void, Never> {
        Task { @MainActor in
            do {
                self.recordingState = .transcribing
                
                let transcriptionStart = Date()
                let transcribedText = try await transcriptionManager.transcribe(audioURL: recordURL)
                let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
                
                let audioAsset = AVURLAsset(url: recordURL)
                let audioDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

                // Check if AI Enhancement is properly configured
                if let aiService = aiService, aiService.isProperlyConfigured() {
                    
                    do {
                        let (enhancedText, enhancementDuration, promptName) = try await aiService.enhance(transcribedText)
                        
                        let transcription = Transcription(
                            text: transcribedText,
                            enhancedText: enhancedText,
                            audioDuration: audioDuration,
                            audioFileName: recordURL.lastPathComponent,
                            transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                            aiEnhancementModelName: aiService.selectedMode.aiModel,
                            promptName: promptName,
                            transcriptionDuration: transcriptionDuration,
                            enhancementDuration: enhancementDuration)
                        
                        modelContext.insert(transcription)
                        try modelContext.save()
                        
                        try Task.checkCancellation()
                        
                        self.recordingState = .idle
                        
                    } catch {
                        // Enhancement failed
                        let transcription = Transcription(
                            text: transcribedText,
                            enhancedText: "Enhancement failed: \(error)",
                            audioDuration: audioDuration,
                            audioFileName: recordURL.lastPathComponent,
                            transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                            transcriptionDuration: transcriptionDuration)
                        
                        modelContext.insert(transcription)
                        try modelContext.save()
                        
                        try Task.checkCancellation()
                        
                        self.recordingState = .idle
                    }
                    
                } else {
                    // NO AI Enhance applied
                    let transcription = Transcription(
                        text: transcribedText,
                        audioDuration: audioDuration,
                        audioFileName: recordURL.lastPathComponent,
                        transcriptionModelName: transcriptionManager.getCurrentTranscriptionModel()?.displayName,
                        transcriptionDuration: transcriptionDuration)
                    
                    modelContext.insert(transcription)
                    try modelContext.save()
                    
                    try Task.checkCancellation()
                    
                    self.recordingState = .idle
                }
                
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
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
            Task { @MainActor in
                guard self.audioPlayer != nil else { return }
                self.audioPlayer.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioPlayer.averagePower(forChannel: 0)) / 160) ))
                self.audioPower = power
            }
        })
    }
    
    func cancelTranscribe() {
        transcribingSpeechTask?.cancel()
        transcribingSpeechTask = nil
        resetValues()
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
}
