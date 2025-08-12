//
//  WhisperState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI
import AVFoundation

@Observable
class WhisperState {
//    var messageLog = ""
    var canTranscribe = false
//    @Published var isRecording = false
    
    private var whisperContext: WhisperContext?
//    private let recorder = Recorder()
    private var recordedFile: URL? = nil
    private var audioPlayer: AVAudioPlayer?
    
//    private var builtInModelUrl: URL? {
//        Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin", subdirectory: "models")
//    }
//    
//    private var sampleUrl: URL? {
//        Bundle.main.url(forResource: "jfk", withExtension: "wav", subdirectory: "samples")
//    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
//    override init() {
//        super.init()
//        loadModel()
//    }
    
    func loadModel(modelUrl: URL? = nil, log: Bool = true) {
        do {
            whisperContext = nil
            if let modelUrl {
                whisperContext = try WhisperContext.createContext(path: modelUrl.path())
            } else {
                print("Could not locate model")
            }
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func transcribeAudio(_ url: URL) async {
        guard canTranscribe else { return }
        guard let whisperContext else { return }
        
        do {
            canTranscribe = false
            
            // Reading wave samples
            let data = try readAudioSamples(url)
            
            // Transcribing data
            await whisperContext.fullTranscribe(samples: data)
            
            let text = await whisperContext.getTranscription()
            print(text)
        } catch {
            print(error.localizedDescription)
        }
        
        canTranscribe = true
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        stopPlayback()
        try startPlayback(url)
        return try decodeWaveFile(url)
    }
    
    func decodeWaveFile(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }
    
//    func toggleRecord() async {
//        if isRecording {
//            await recorder.stopRecording()
//            isRecording = false
//            if let recordedFile {
//                await transcribeAudio(recordedFile)
//            }
//        } else {
//            requestRecordPermission { granted in
//                if granted {
//                    Task {
//                        do {
//                            self.stopPlayback()
//                            let file = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
//                                .appending(path: "output.wav")
//                            try await self.recorder.startRecording(toOutputFile: file, delegate: self)
//                            self.isRecording = true
//                            self.recordedFile = file
//                        } catch {
//                            print(error.localizedDescription)
//                            self.messageLog += "\(error.localizedDescription)\n"
//                            self.isRecording = false
//                        }
//                    }
//                }
//            }
//        }
//    }
    
//    private func requestRecordPermission(response: @escaping (Bool) -> Void) {
//#if os(macOS)
//        response(true)
//#else
//        AVAudioSession.sharedInstance().requestRecordPermission { granted in
//            response(granted)
//        }
//#endif
//    }
    
    private func startPlayback(_ url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // MARK: AVAudioRecorderDelegate
    
//    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
//        if let error {
//            Task {
//                await handleRecError(error)
//            }
//        }
//    }
    
//    private func handleRecError(_ error: Error) {
//        print(error.localizedDescription)
//        messageLog += "\(error.localizedDescription)\n"
//        isRecording = false
//    }
    
//    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
//        Task {
//            await onDidFinishRecording()
//        }
//    }
    
//    private func onDidFinishRecording() {
//        isRecording = false
//    }
}


//fileprivate func cpuCount() -> Int {
//    ProcessInfo.processInfo.processorCount
//}
