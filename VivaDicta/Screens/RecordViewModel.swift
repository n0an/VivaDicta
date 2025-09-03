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
    var appState: AppState?
    
    // TODO: Add auto stop feature later
//    var recordingTimer: Timer?
//    var prevAudioPower: Double?
    
    init(appState: AppState?) {
        self.appState = appState
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
    
    override init() {
        super.init()
        
        // Skip audio session setup during testing or CI
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                            ProcessInfo.processInfo.environment["CI"] != nil ||
                            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil ||
                            NSClassFromString("XCTestCase") != nil
        
        if isRunningTests {
            print("RecordViewModel: Skipping audio setup - detected test/CI environment")
            return
        }
        
        #if !os(macOS)
        do {
            #if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #endif
            try recordingSession.setActive(true)
            
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                Task { @MainActor [weak self] in
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
                Task { @MainActor [unowned self] in
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
        Task { @MainActor [unowned self] in
            do {
                self.recordingState = .transcribing
                
                if let transcriptionService = appState?.transcriptionService {
                    let transcribedText = try await transcriptionService.generateAudioTransciptions(fileURL: recordURL)
                    print(transcribedText)
                    
                    
                    let transcribedTextArr = transcribedText.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    let maxTitleWords = min(transcribedTextArr.count, 3)
                    
                    let title = Array(transcribedTextArr[0..<maxTitleWords]).joined(separator: " ")
                    
                    let transcription = Transcription(
                        title: title,
                        text: transcribedText,
                        timestamp: .now,
                        enhancedText: "mock",
                        audioFileURL: recordURL.absoluteString,
                        transcriptionModelName: "whisper",
                        enhancementModelName: "none")
                    
                    modelContext.insert(transcription)
                    try modelContext.save()
                }
                
//                let whisperCPPTranscriptionService = LocalWhisperTranscriptionService()
//                let transcribedText = try await whisperCPPTranscriptionService.generateAudioTransciptions(fileURL: recordURL)
                
//                let whisperCPPTranscriptionService = WhisperState()
//                await whisperCPPTranscriptionService.loadAndTranscribe(recordURL)
                
//                let audioData = try Data(contentsOf: captureURL)
//                
//                let openAITranscriptionService = OpenAITranscriptionService()
//                
//                let transcribedText = try await openAITranscriptionService.generateAudioTransciptions(audioData: audioData)
                
                try Task.checkCancellation()
                
//                print(transcribedText)
                self.recordingState = .idle
                
//                let transcription = Transcription(
//                    title: "test",
//                    text: transcribedText,
//                    timestamp: .now,
//                    enhancedText: "mock",
//                    audioFileURL: "mock",
//                    transcriptionModelName: "whisper",
//                    enhancementModelName: "none")
//                
//                modelContext.insert(transcription)
//                try modelContext.save()
                //                try Task.checkCancellation()
//                let responseText = try await client.promptChatGPT(prompt: prompt)
                
//                try Task.checkCancellation()
//                let data = try await client.generateSpeechFrom(input: responseText, voice:
//                        .init(rawValue: selectedVoice.rawValue) ?? .alloy)
                
//                try Task.checkCancellation()
//                try self.playAudio(data: data)
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
            Task { @MainActor [unowned self] in
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
        Task { @MainActor [unowned self] in
            if !flag {
                resetValues()
                recordingState = .idle
            }
        }
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [unowned self] in
            resetValues()
            recordingState = .idle
        }
    }
}
