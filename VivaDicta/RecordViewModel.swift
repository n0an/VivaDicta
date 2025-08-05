//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 03.08.2025.
//

import SwiftUI
import Foundation
import AVFoundation

enum RecordingState {
    case idle
    case recording
    case transcribing
    case completed
    case error(RecordError)
    
}

enum RecordError: Error {
    case avInitError
    case userDenied
    case recordError
    case other
}

@Observable
class RecordViewModel: NSObject, @MainActor AVAudioRecorderDelegate {
    var audioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!
    #if !os(macOS)
    var recordingSession = AVAudioSession.sharedInstance()
    #endif
    
    var animationTimer: Timer?
    var recordingTimer: Timer?
    var prevAudioPower: Double?
    
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
        #if !os(macOS)
        do {
            #if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #endif
            try recordingSession.setActive(true)
            
            AVAudioApplication.requestRecordPermission { [weak self] allowed in
                if !allowed {
                    self?.recordingState = .error(.userDenied)
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
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: captureURL,
                                                settings: settings)
            audioRecorder.isMeteringEnabled = true
            audioRecorder.delegate = self
            audioRecorder.record()
            
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                self.audioPower = power
            })
            
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                if self.prevAudioPower == nil {
                    self.prevAudioPower = power
                    return
                }
                if let prevAudioPower = self.prevAudioPower, prevAudioPower < 0.25 && power < 0.175 {
                    self.finishCaptureAudio()
                    return
                }
                self.prevAudioPower = power
            })
            
        } catch {
            resetValues()
            recordingState = .error(.recordError)
        }
    }
    
    func finishCaptureAudio() {
        resetValues()
        do {
            let data = try Data(contentsOf: captureURL)
            
            print("HERE")
            
//            processingSpeechTask = processSpeechTask(audioData: data)
        } catch {
            recordingState = .error(.recordError)
        }
    }
    
    func stopCaptureAudio() {
        resetValues()
        recordingState = .transcribing
    }
    
    func cancelTranscribe() {
        recordingState = .idle
    }
    
    func resetValues() {
        audioPower = 0
        prevAudioPower = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            resetValues()
            recordingState = .idle
        }
    }
    
}
