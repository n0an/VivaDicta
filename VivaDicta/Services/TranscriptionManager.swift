//
//  TranscriptionManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.02
//

import Foundation

@Observable
class TranscriptionManager {
    
    // MARK: - Properties
    
    private(set) var transcriptionService: (any TranscriptionService)?
    private let settingsManager: SettingsManager
    
    var selectedLanguage: Language {
        didSet {
            updateServiceLanguage()
            settingsManager.saveSelectedLanguage(selectedLanguage)
        }
    }
    
    // MARK: - Computed Properties
    
    var canTranscribe: Bool {
        transcriptionService != nil
    }
    
    // MARK: - Initialization
    
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        self.selectedLanguage = settingsManager.loadSelectedLanguage()
    }
    
    // MARK: - Service Management
    
    func createLocalTranscriber(with model: WhisperModel) {
        transcriptionService = LocalWhisperTranscriptionService(
            selectedModel: model,
            selectedLanguage: selectedLanguage
        )
    }
    
    func createCloudTranscriber(type: CloudTranscriptionModel) {
        switch type {
        case .openAI:
            transcriptionService = OpenAITranscriptionService(selectedLanguage: selectedLanguage)
        case .elevenlabs, .groq:
            // TODO: Implement other cloud services
            break
        }
    }
    
    func clearTranscriber() {
        transcriptionService = nil
    }
    
    // MARK: - Language Management
    
    private func updateServiceLanguage() {
        transcriptionService?.selectedLanguage = selectedLanguage
    }
    
    func setLanguage(_ language: Language) {
        selectedLanguage = language
    }
    
    // MARK: - Transcription Operations
    
    func transcribe(audioFileURL: URL) async throws -> String {
        guard let transcriptionService else {
            throw TranscriptionError.noServiceAvailable
        }
        
        return try await transcriptionService.generateAudioTransciptions(fileURL: audioFileURL)
    }
}

// MARK: - Errors

enum TranscriptionError: Error, LocalizedError {
    case noServiceAvailable
    case serviceNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .noServiceAvailable:
            return "No transcription service is available"
        case .serviceNotConfigured:
            return "Transcription service is not properly configured"
        }
    }
}