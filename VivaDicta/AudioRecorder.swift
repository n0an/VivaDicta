//
//  AudioRecorder.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.04
//

import SwiftUI
import AVFoundation
import AVFAudio

struct Record {
    var name: String
    var fileURL: String
    
}


@Observable
class AudioRecorder {
    enum RecordingState {
        case idle
        case recording
        case completed(Record)
    }
    
    var recordingState: RecordingState = .idle
    
    private var recordingSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?
    private let temporaryURL = URL.documentsDirectory.appending(path: "recording.m4a")
    
    private var audioPermissionStatus: AVAudioApplication.recordPermission = .undetermined
   
    
    func requestAudioPermission() async {
        if await AVAudioApplication.requestRecordPermission() {
            self.audioPermissionStatus = .granted
        } else {
            self.audioPermissionStatus = .denied
        }
    }
    
    func recordAudio() {
        Task {
            if audioPermissionStatus != .granted {
                await requestAudioPermission()
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
        Task {
            audioRecorder?.stop()
            
            let id = UUID()
            let filename = "\(id.uuidString).m4a"
            
            let fileURL = URL.documentsDirectory.appending(path: filename)
            
            let record = Record(name: "test", fileURL: fileURL.absoluteString)
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
                recordingState = .completed(record)
            } catch {
                print(error.localizedDescription)
                recordingState = .idle
            }
            print(fileURL)
        }
        
        
        
    }
}


