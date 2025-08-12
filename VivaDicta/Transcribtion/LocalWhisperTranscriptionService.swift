//
//  LocalWhisperTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import whisper

struct LocalWhisperTranscriptionService: TranscribtionService {
    public func generateAudioTransciptions(fileURL: URL) async throws -> String {
        return await loadAndTranscribe(fileURL)
    }
    
    private func loadAndTranscribe(_ url: URL) async -> String {
        do {
            let whisperContext = try WhisperContext.createContext(path: URL.documentsDirectory.appendingPathComponent("tiny.bin").path())
            
            let data = try readAudioSamples(url)
            await whisperContext.fullTranscribe(samples: data)
            let text = await whisperContext.getTranscription()
            return text
            
        } catch {
            print(error.localizedDescription)
            return ""
        }
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
