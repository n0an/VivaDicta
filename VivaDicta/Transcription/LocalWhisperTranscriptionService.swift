//
//  LocalWhisperTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import whisper

struct LocalWhisperTranscriptionService: TranscriptionService {
    
    var selectedModel: WhisperModel
    var selectedLanguage: Language
    
    private var whisperContext: WhisperContext?
    
    init(selectedModel: WhisperModel, selectedLanguage: Language) {
        self.selectedModel = selectedModel
        self.selectedLanguage = selectedLanguage
        
        do {
            whisperContext = try WhisperContext.createContext(path: selectedModel.fileURL.path())
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    public func generateAudioTransciptions(fileURL: URL) async throws -> String {
        return try await transcribeAudio(fileURL)
    }
    
    public func transcribeAudio(_ url: URL) async throws -> String {
        guard let whisperContext else { return "" }
        
        await whisperContext.setPrompt(selectedLanguage.prompt)
        print("=== Language = \(selectedLanguage.prompt)")
        let data = try readAudioSamples(url)
        
        let success = await whisperContext.fullTranscribe(samples: data)
        
        guard success else {
            throw WhisperStateError.whisperCoreFailed
        }
        
        return await whisperContext.getTranscription()
        
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
