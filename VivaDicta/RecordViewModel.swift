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

struct RecordError: Error {
    
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
    
    
    func startCaptureAudio() {
        recordingState = .recording
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
