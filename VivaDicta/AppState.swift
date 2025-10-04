//
//  AppState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI
import ActivityKit

@Observable
class AppState {
    var liveActivity: Activity<VivaDictaLiveActivityAttributes>? = nil
    
    var transcriptionManager: TranscriptionManager!
    var aiService: AIService!
    private let lifecycleManager = AppLifecycleManager.shared

    var selectedTab: TabTag = .record
    var shouldNavigateToModels: Bool = false

    init() {
        transcriptionManager = TranscriptionManager()
        aiService = AIService()

        // Set up callbacks to coordinate between services
        aiService.onModeChange = { [weak self] newMode in
            self?.handleModeChange(newMode)
        }

        transcriptionManager.onCloudModelsUpdate = { [weak self] in
            self?.handleCloudModelsUpdate()
        }

        // Initialize TranscriptionManager with the current mode
        transcriptionManager.setCurrentMode(aiService.selectedMode)

        // Start app lifecycle tracking
        lifecycleManager.startTracking()

        // Preload WhisperKit model if conditions are met
        Task {
            await preloadWhisperKitModelIfNeeded()
        }
    }

    // This method is called when AIService changes its mode
    public func handleModeChange(_ newMode: FlowMode) {
        // Update TranscriptionManager's current mode
        transcriptionManager.setCurrentMode(newMode)

        // Trigger preload if the new mode uses WhisperKit
        Task {
            await preloadWhisperKitModelIfNeeded()
        }
    }

    // This method is called when TranscriptionManager updates cloud models
    public func handleCloudModelsUpdate() {
        // Notify AIService to refresh its connected providers
        aiService.refreshConnectedProviders()
    }

    // Preload WhisperKit model on app startup or mode change
    private func preloadWhisperKitModelIfNeeded() async {
        await transcriptionManager.preloadWhisperKitModelIfNeeded()
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        return try await transcriptionManager.transcribe(audioURL: audioURL)
    }
    
    
    
    func startLiveActivity() {
        // Ensure lifecycle tracking is active when launched from keyboard
        lifecycleManager.startTracking()

        let attributes = VivaDictaLiveActivityAttributes(name: "testName")
        do {

            let activityContent = ActivityContent(state: VivaDictaLiveActivityAttributes.ContentState(emoji: "smile"), staleDate: .now.addingTimeInterval(60))

            liveActivity = try Activity.request(attributes: attributes, content: activityContent)

        } catch {
            print(error.localizedDescription)
        }
    }
}

// MARK: - Global
enum TabTag {
    case record
    case transcriptions
    case settings
}
