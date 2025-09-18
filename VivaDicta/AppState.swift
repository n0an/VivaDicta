//
//  AppState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI

@Observable
class AppState {
    // TODO: - move this properties to TranscriptionManager.
    var whisperContext: WhisperContext?
    
    var transcriptionManager: TranscriptionManager!
    
    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
    
    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }
    // TODO: - move this properties to TranscriptionManager. Handle all localTranscriptionService preparing in the TranscriptionManager
    var localTranscriptionService: LocalTranscriptionService!
    private var cloudTranscriptionService = CloudTranscriptionService()
    
    let whisperPrompt = WhisperPrompt()
    var aiService = AIService()
    var promptsManager = PromptsManager()
    
    var selectedTab: TabTag = .record

    init() {
        localTranscriptionService = LocalTranscriptionService(appState: self)
        transcriptionManager = TranscriptionManager(
            appState: self,
            aiService: aiService,
            whisperPrompt: whisperPrompt,
            whisperContext: whisperContext
        )
        
        aiService.transcriptionManager = transcriptionManager
        // Apply selected mode's language on startup
        transcriptionManager.applyModeLanguage(aiService.selectedMode)
//        loadCurrentTranscriptionModel()
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        return try await transcriptionManager.transcribe(audioURL: audioURL)
    }
    
    // TODO: - Load model when tap Record button, and load model only if it's a local model and not already loaded
    func loadLocalModel(_ model: WhisperLocalModel) async throws {
        // TODO: - Add whisperContext release after transcribing?
        do {
            whisperContext = try await WhisperContext.createContext(path: model.fileURL.path)

        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    func updateCloudModels() {
        allAvailableModels = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        aiService.refreshConnectedProviders()
    }
    
}

// MARK: - Global
enum TabTag {
    case record
    case transcriptions
    case models
    case settings
}

// MARK: - save / load local transcription model
//extension AppState {
//    func loadCurrentTranscriptionModel() {
//        if let savedModelName = UserDefaults.standard.string(forKey: Constants.kCurrentTranscriptionModel),
//           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
//            if savedModel.provider == .local,
//               let localWhipserModel = savedModel as? WhisperLocalModel {
//                Task { try await loadLocalModel(localWhipserModel) }
//            }
//            currentTranscriptionModel = savedModel
//        }
//    }
//    
//    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
//        self.currentTranscriptionModel = model
//        
//        UserDefaults.standard.set(model.name, forKey: Constants.kCurrentTranscriptionModel)
//        UserDefaults.standard.synchronize()
//        
//        if model.provider == .local,
//           let localWhipserModel = model as? WhisperLocalModel {
//            Task { try await loadLocalModel(localWhipserModel) }
//        }
//    }
//}
