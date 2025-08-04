//
//  RecordViewModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 03.08.2025.
//

import SwiftUI

@Observable
class RecordViewModel {
    
    var isRecording = false {
        didSet {
            print("record tapped")
            if isRecording {
                audioRecorder.recordAudio()
            } else {
                audioRecorder.stopRecording()
            }
        }
    }
    
    var audioRecorder = AudioRecorder()
    
    
    
    
}
