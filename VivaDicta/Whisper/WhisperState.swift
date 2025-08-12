//
//  WhisperState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI

@Observable
class WhisperState {
    var canTranscribe = false
    
    private var whisperContext: WhisperContext?
    
    func loadAndTranscribe(_ url: URL) async {
        loadModel(modelUrl: URL.documentsDirectory.appendingPathComponent("tiny.bin"))
        await transcribeAudio(url)
    }
    
    func loadModel(modelUrl: URL? = nil) {
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
            
            let data = try readAudioSamples(url)
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
            print(text)
        } catch {
            print(error.localizedDescription)
        }
        
        canTranscribe = true
    }
    
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }
}
