
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.17
//

import SwiftUI
import Foundation

@Observable
class TranscriptionManager {
    var whisperContext: WhisperContext?
    private let whisperPrompt: WhisperPrompt
    private var localTranscriptionService: LocalTranscriptionService!
    private let cloudTranscriptionService = CloudTranscriptionService()
    private(set) var currentMode: FlowMode = FlowMode.defaultMode

    // Callback for when cloud models are updated
    public var onCloudModelsUpdate: (() -> Void)?

    var allAvailableModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels

    var availableWhisperLocalModels: [WhisperLocalModel] {
        TranscriptionModelProvider.allLocalModels.filter { $0.fileExists }
    }

    var selectedLanguage: String {
        get {
            UserDefaults.standard.string(forKey: Constants.kSelectedLanguageKey) ?? "en"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Constants.kSelectedLanguageKey)
        }
    }

    init() {
        self.whisperPrompt = WhisperPrompt()
        self.localTranscriptionService = LocalTranscriptionService(transcriptionManager: self)
    }
    
    public func setCurrentMode(_ mode: FlowMode) {
        currentMode = mode
        applyModeLanguage(mode)

        // Preheat Local Whisper Model if needed
        if mode.transcriptionProvider == .local {
            if let localModel = TranscriptionModelProvider.allLocalModels.first(where: { $0.name == mode.transcriptionModel }) {
                Task {
                    try? await preheatLocalModel(localModel)
                }
            }
        }
    }
    
    func preheatLocalModel(_ model: WhisperLocalModel) async throws {
        do {
            whisperContext = try await WhisperContext.createContext(path: model.fileURL.path)
        } catch {
            throw WhisperStateError.modelLoadFailed
        }
    }
    
    private func updateLanguage(_ language: String) {
        selectedLanguage = language
        whisperPrompt.updateTranscriptionPrompt()
    }
    
    private func applyModeLanguage(_ mode: FlowMode) {
        let language = mode.transcriptionLanguage ?? "auto"
        updateLanguage(language)
    }
    

    public func updateCloudModels() {
        allAvailableModels = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels
        onCloudModelsUpdate?()
    }
    
    
    public func getCurrentTranscriptionModel() -> (any TranscriptionModel)? {
        let provider = currentMode.transcriptionProvider
        let modelName = currentMode.transcriptionModel

        let allModels: [any TranscriptionModel] = TranscriptionModelProvider.allLocalModels + TranscriptionModelProvider.allCloudModels

        return allModels.first { model in
            model.provider == provider && model.name == modelName
        }
    }
    
    public func transcribe(audioURL: URL) async throws -> String {
        guard let model = getCurrentTranscriptionModel() else {
            throw WhisperStateError.transcriptionFailed
        }
        
        let transcriptionService: any TranscriptionService
        switch model.provider {
        case .local:
            transcriptionService = localTranscriptionService
        default:
            transcriptionService = cloudTranscriptionService
        }
        
        return try await transcriptionService.transcribe(audioURL: audioURL, model: model)
    }
}
