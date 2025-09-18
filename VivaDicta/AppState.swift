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
    var transcriptionManager: TranscriptionManager!
    var aiService: AIService!
    var promptsManager = PromptsManager()
    
    var selectedTab: TabTag = .record

    init() {
        transcriptionManager = TranscriptionManager()
        aiService = AIService(transcriptionManager: transcriptionManager)
        transcriptionManager.aiService = aiService
        transcriptionManager.applyModeLanguage(aiService.selectedMode)
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        return try await transcriptionManager.transcribe(audioURL: audioURL)
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
