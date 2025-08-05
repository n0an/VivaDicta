//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 03.08.2025.
//

import SwiftUI
import Foundation

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
class RecordViewModel {
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
    
    func stopCaptureAudio() {
        recordingState = .transcribing
    }
    
    func startCaptureAudio() {

        recordingState = .recording

    }
    
}
