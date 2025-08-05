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
    
    func stopCaptureAudio() {
        recordingState = .transcribing
    }
    
    func startCaptureAudio() {

        recordingState = .recording

    }
    
}
