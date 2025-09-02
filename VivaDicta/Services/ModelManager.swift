//
//  ModelManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation

@Observable
class ModelManager {
    
    // MARK: - Properties
    
    private(set) var selectedModel: WhisperModel?
    private let settingsManager: SettingsManager
    private let downloadManager = WhisperModelDownloadManager()
    
    // MARK: - Computed Properties
    
    var availableModels: [WhisperModel] {
        WhisperModel.downloadedModels
    }
    
    var hasSelectedModel: Bool {
        selectedModel?.fileExists == true
    }
    
    var canUseSelectedModel: Bool {
        guard let selectedModel else { return false }
        return selectedModel.fileExists
    }
    
    // MARK: - Initialization
    
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        
        // Restore selected model from settings
        if let savedModel = settingsManager.loadSelectedModel() {
            self.selectedModel = savedModel
        }
    }
    
    // MARK: - Model Selection
    
    func selectModel(_ model: WhisperModel) -> Bool {
        guard model.fileExists else { 
            return false 
        }
        
        selectedModel = model
        settingsManager.saveSelectedModel(model)
        return true
    }
    
    // MARK: - Download Management
    
    func downloadModel(_ model: WhisperModel) async throws {
        try await downloadManager.downloadModel(model)
    }
    
    func downloadProgress(for model: WhisperModel) -> Double {
        downloadManager.currentProgress(for: model)
    }
    
    func downloadStatus(for model: WhisperModel) -> DownloadStatus {
        downloadManager.downloadStatus(for: model)
    }
    
    func handleDownloadError(_ model: WhisperModel, _ error: any Error) async {
        await downloadManager.handleModelDownloadError(model, error)
    }
    
    // MARK: - Model Validation
    
    func validateSelectedModel() {
        guard let selectedModel,
              !selectedModel.fileExists else { return }
        
        // Selected model no longer exists, clear it
        self.selectedModel = nil
    }
    
    // MARK: - Access to Download Manager
    
    var modelDownloadManager: WhisperModelDownloadManager {
        downloadManager
    }
}