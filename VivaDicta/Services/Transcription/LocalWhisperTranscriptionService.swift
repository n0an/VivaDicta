//
//  LocalWhisperTranscriptionService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import whisper


class LocalTranscriptionService: TranscriptionService {
    
    private var whisperContext: WhisperContext?
//    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "LocalTranscriptionService")
    private weak var appState: AppState?
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model.provider == .local else {
            throw WhisperStateError.modelLoadFailed
        }
        
//        logger.notice("Initiating local transcription for model: \(model.displayName)")
        
        // Check if the required model is already loaded in AppState
        if let appState = appState,
           let loadedContext = await appState.whisperContext,
            let currentModel = await appState.currentTranscriptionModel,
            currentModel.provider == .local,
            currentModel.name == model.name {
            
//            logger.notice("✅ Using already loaded model: \(model.name)")
            whisperContext = loadedContext
        } else {
            // TODO: Important - remove this branch of logic, make it reliable instead
            // Model not loaded or wrong model loaded, proceed with loading
            // Resolve the on-disk URL using AppState.availableModels (covers imports)
            let resolvedURL: URL? = await appState?.availableModels.first(where: { $0.name == model.name })?.fileURL
            guard let modelURL = resolvedURL, FileManager.default.fileExists(atPath: modelURL.path) else {
//                logger.error("Model file not found for: \(model.name)")
                throw WhisperStateError.modelLoadFailed
            }
            
//            logger.notice("Loading model: \(model.name)")
            do {
                whisperContext = try await WhisperContext.createContext(path: modelURL.path)
            } catch {
//                logger.error("Failed to load model: \(model.name) - \(error.localizedDescription)")
                throw WhisperStateError.modelLoadFailed
            }
        }
        
        guard let whisperContext = whisperContext else {
//            logger.error("Cannot transcribe: Model could not be loaded")
            throw WhisperStateError.modelLoadFailed
        }
        
        // Read audio data
        let data = try readAudioSamples(audioURL)
        
        // Set prompt
        let currentPrompt = UserDefaults.standard.string(forKey: kTranscriptionPrompt) ?? ""
        await whisperContext.setPrompt(currentPrompt)
        
        // Transcribe
        let success = await whisperContext.fullTranscribe(samples: data)
        
        guard success else {
//            logger.error("Core transcription engine failed (whisper_full).")
            throw WhisperStateError.whisperCoreFailed
        }
        
        var text = await whisperContext.getTranscription()
        
        if UserDefaults.standard.object(forKey: "IsTextFormattingEnabled") as? Bool ?? true {
//            text = WhisperTextFormatter.format(text)
        }
        
//        logger.notice("✅ Local transcription completed successfully.")
        
        // Only release resources if we created a new context (not using the shared one)
        if await appState?.whisperContext !== whisperContext {
            await whisperContext.releaseResources()
            self.whisperContext = nil
        }
        
        return text
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










//struct LocalWhisperTranscriptionService: TranscriptionService {
//    
//    var selectedModel: WhisperLocalModel
//    var selectedLanguage: Language
//    
//    private var whisperContext: WhisperContext?
//    
//    init(selectedModel: WhisperLocalModel, selectedLanguage: Language) {
//        self.selectedModel = selectedModel
//        self.selectedLanguage = selectedLanguage
//        
//        do {
//            whisperContext = try WhisperContext.createContext(path: selectedModel.fileURL.path())
//            
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
//    
//    public func generateAudioTransciptions(fileURL: URL) async throws -> String {
//        return await transcribeAudio(fileURL)
//    }
//    
//    public func transcribeAudio(_ url: URL) async -> String {
//        guard let whisperContext else { return "" }
//        
//        do {
//            await whisperContext.setPrompt(selectedLanguage.prompt)
//            print("=== Language = \(selectedLanguage.prompt)")
//            let data = try readAudioSamples(url)
//            await whisperContext.fullTranscribe(samples: data)
//            let text = await whisperContext.getTranscription()
//            return text
//        } catch {
//            print(error.localizedDescription)
//            return ""
//        }
//    }
//    
//    private func readAudioSamples(_ url: URL) throws -> [Float] {
//        let data = try Data(contentsOf: url)
//        let floats = stride(from: 44, to: data.count, by: 2).map {
//            return data[$0..<$0 + 2].withUnsafeBytes {
//                let short = Int16(littleEndian: $0.load(as: Int16.self))
//                return max(-1.0, min(Float(short) / 32767.0, 1.0))
//            }
//        }
//        return floats
//    }
//}
