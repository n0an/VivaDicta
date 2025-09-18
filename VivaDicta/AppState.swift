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
        transcriptionManager.handleModeChange(aiService.selectedMode)
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
