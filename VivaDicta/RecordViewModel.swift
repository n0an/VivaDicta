//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 03.08.2025.
//

import SwiftUI

@Observable
class RecordViewModel {
    var audioRecorder = AudioRecorder()
    
    var recordButtonParams: (String, String) {
        switch audioRecorder.recordingState {
        case .idle:
            ("Record", "record.circle")
        case .recording:
            ("Stop", "stop.circle")
        case .transcribing:
            ("Record", "record.circle")
        case .completed:
            ("Record", "record.circle")
//        case .error(let error):
//            ("Record", "record.circle")
        }
    }
    
    func recordButtonTapped() {
        print("record button tapped")
        if audioRecorder.recordingState != .recording {
            audioRecorder.recordAudio()
        } else {
            audioRecorder.stopRecording()
        }
    }
    
}
