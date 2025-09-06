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
    var whisperContext: WhisperContext?
    var currentTranscriptionModel: (any TranscriptionModel)?
    
    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
    
    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }
    
    private var localTranscriptionService: LocalTranscriptionService!
    private var cloudTranscriptionService = CloudTranscriptionService()
    
    let whisperPrompt = WhisperPrompt()
    
    var selectedTab: TabTag = .record

    init() {
        localTranscriptionService = LocalTranscriptionService(appState: self)
        loadCurrentTranscriptionModel()
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        guard let model = currentTranscriptionModel else {
            throw WhisperStateError.transcriptionFailed
        }

        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .local:
            transcriptionService = localTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }

        let transcriptionStart = Date()
        let text = try await transcriptionService.transcribe(audioURL: audioURL, model: model)
        let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
        return text
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
    
    func updateCloudModels(with model: CloudModel, apiKey: String) {
        CloudModel.saveApiKey(apiKey, model: model)
        allAvailableModels = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
    }
    
    func updateTranscriptionPrompt() {
        whisperPrompt.updateTranscriptionPrompt()
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
extension AppState {
    func loadCurrentTranscriptionModel() {
        if let savedModelName = UserDefaults.standard.string(forKey: Constants.kCurrentTranscriptionModel),
           let savedModel = allAvailableModels.first(where: { $0.name == savedModelName }) {
            print("=== \(savedModel.name)")
            if savedModel.provider == .local,
               let localWhipserModel = savedModel as? WhisperLocalModel {
                Task { try await loadLocalModel(localWhipserModel) }
            }
            currentTranscriptionModel = savedModel
        }
    }
    
    func setDefaultTranscriptionModel(_ model: any TranscriptionModel) {
        self.currentTranscriptionModel = model
        print("=== \(model.name)")
        
        UserDefaults.standard.set(model.name, forKey: Constants.kCurrentTranscriptionModel)
        UserDefaults.standard.synchronize()
        
        if model.provider == .local,
           let localWhipserModel = model as? WhisperLocalModel {
            Task { try await loadLocalModel(localWhipserModel) }
        }
        
        // Post notification about the model change
//        NotificationCenter.default.post(name: .didChangeModel, object: nil, userInfo: ["modelName": model.name])
//        NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
    }
}
