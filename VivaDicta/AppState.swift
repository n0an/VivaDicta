//
//  AppState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//

import Foundation
import SwiftUI
import ActivityKit
import os

@Observable
class AppState {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AppState")

    var liveActivity: Activity<VivaDictaLiveActivityAttributes>? = nil
    private var liveActivityTimer: Timer?
    private var liveActivityStartTime: Date?

    var transcriptionManager: TranscriptionManager!
    var aiService: AIService!
    var recordViewModel: RecordViewModel!
//    private let lifecycleManager = AppLifecycleManager.shared

    var selectedTab: TabTag = .record
    var shouldNavigateToModels: Bool = false

    init() {
        transcriptionManager = TranscriptionManager()
        aiService = AIService()
        recordViewModel = RecordViewModel(appState: self)

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
//        lifecycleManager.startTracking()

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
//        lifecycleManager.startTracking()

        guard liveActivity == nil else { return }

        // Cancel any existing timer
        liveActivityTimer?.invalidate()

        let attributes = VivaDictaLiveActivityAttributes(name: "testName")
        do {
            // Set both staleDate (for system UI hints) and dismissalPolicy
            let activityContent = ActivityContent(
                state: VivaDictaLiveActivityAttributes.ContentState(emoji: "smile"),
                staleDate: Calendar.current.date(byAdding: .minute, value: 10, to: .now)
            )

            liveActivity = try Activity.request(attributes: attributes, content: activityContent)

            // Store the start time
            liveActivityStartTime = Date()

            // Set up timer to end the activity after 10 minutes
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
                Task {
                    await self?.endLiveActivity()
                }
            }

        } catch {
            logger.error("🤺 Error starting Live Activity \(error.localizedDescription)")
        }
    }

    func endLiveActivity() async {
        guard let liveActivity else { return }

        // Cancel the timer
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil

        // End the Live Activity immediately without updating content
        await liveActivity.end(nil, dismissalPolicy: .immediate)

        self.liveActivity = nil
        self.liveActivityStartTime = nil
        logger.info("Live Activity ended")
    }

    /// Check if the Live Activity is stale and end it if necessary
    /// Called when the app returns to foreground
    public func checkAndEndStaleLiveActivity() {
        guard liveActivity != nil,
              let startTime = liveActivityStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let maxDuration: TimeInterval = 600 // 10 minutes in seconds

        if elapsed >= maxDuration {
            logger.info("Live Activity is stale (elapsed: \(elapsed) seconds), ending it")
            Task {
                await endLiveActivity()
            }
        } else {
            // Reschedule the timer for the remaining time
            let remainingTime = maxDuration - elapsed
            logger.info("Live Activity still valid. Rescheduling timer for \(remainingTime) seconds")

            // Cancel existing timer and create a new one
            liveActivityTimer?.invalidate()
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.endLiveActivity()
                }
            }
        }
    }
}

// MARK: - Global
enum TabTag {
    case record
    case transcriptions
    case settings
}
