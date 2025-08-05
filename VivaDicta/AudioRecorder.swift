//
//  AudioRecorder.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.04
//

import SwiftUI
import AVFoundation

struct Record {
    var name: String
    var fileURL: String
    
}

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case completed
}


@Observable
class AudioRecorder {
    var recordingState: RecordingState = .idle
    
    private var recordingSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?
    private let temporaryURL = URL.documentsDirectory.appending(path: "recording.m4a")
    
    private var audioPermissionStatus: AVAudioApplication.recordPermission = .undetermined
    
    
    
    func recordAudio() {
        Task {
            if self.audioPermissionStatus == .undetermined {
                self.audioPermissionStatus = await hasPermissionToRecord() ? .granted : .denied
                guard self.audioPermissionStatus == .granted else {
                    print("record is prohibitted")
                    return
                }
            } else {
                // Open iOS Settings here
            }
            
            
            let settings = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1
            ]
            
            do {
                try recordingSession.setCategory(.playAndRecord)
                try recordingSession.setActive(true)
                
                audioRecorder = try AVAudioRecorder(url: temporaryURL, settings: settings)
                audioRecorder?.record()
                recordingState = .recording
            } catch {
                print(error.localizedDescription)
            }
        }
        
        
        
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        
        let id = UUID()
        let filename = "\(id.uuidString).m4a"
        
        let fileURL = URL.documentsDirectory.appending(path: filename)
        
        let record = Record(name: "test", fileURL: fileURL.absoluteString)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            recordingState = .completed
        } catch {
            print(error.localizedDescription)
            recordingState = .idle
        }
        print(fileURL)
        
        
    }
    
    private func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}


