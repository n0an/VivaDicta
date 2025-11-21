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
import CoreSpotlight
import SwiftData

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

    // Navigation state
    var shouldNavigateToModels: Bool = false
    var shouldStartRecording: Bool = false
    var selectedTranscriptionID: UUID? = nil  // For Spotlight navigation
    var showKeyboardFlowSheet: Bool = false  // For showing keyboard flow activation sheet

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

        // Note: Spotlight indexing is now done on-demand when transcriptions are created/deleted
        // No longer doing batch indexing on app startup
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

        let attributes = VivaDictaLiveActivityAttributes(name: "VivaDicta")
        do {
            // Set both staleDate (for system UI hints) and dismissalPolicy
            let activityContent = ActivityContent(
                state: VivaDictaLiveActivityAttributes.ContentState(state: .idle),
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
            logger.logError("🤺 Error starting Live Activity \(error.localizedDescription)")
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
        logger.logInfo("Live Activity ended")
    }

    /// Update the Live Activity state (recording, transcribing, enhancing, etc.)
    func updateLiveActivityState(_ state: LiveActivityState) async {
        guard let liveActivity else { return }

        let updatedContent = ActivityContent(
            state: VivaDictaLiveActivityAttributes.ContentState(state: state),
            staleDate: Calendar.current.date(byAdding: .minute, value: 10, to: .now)
        )

        await liveActivity.update(updatedContent)
        logger.logInfo("📱 Updated Live Activity state to: \(state.rawValue)")
    }

    /// Check if the Live Activity is stale and end it if necessary
    /// Called when the app returns to foreground
    public func checkAndEndStaleLiveActivity() {
        guard liveActivity != nil,
              let startTime = liveActivityStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let maxDuration: TimeInterval = 600 // 10 minutes in seconds

        if elapsed >= maxDuration {
            logger.logInfo("Live Activity is stale (elapsed: \(elapsed) seconds), ending it")
            Task {
                await endLiveActivity()
            }
        } else {
            // Reschedule the timer for the remaining time
            let remainingTime = maxDuration - elapsed
            logger.logInfo("Live Activity still valid. Rescheduling timer for \(remainingTime) seconds")

            // Cancel existing timer and create a new one
            liveActivityTimer?.invalidate()
            liveActivityTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.endLiveActivity()
                }
            }
        }
    }
    
    /// Index a single transcription in Spotlight
    func indexTranscriptionToSpotlight(_ transcription: Transcription) async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.logError("[Spotlight] Indexing is unavailable")
            return
        }

        let item = CSSearchableItem(
            uniqueIdentifier: transcription.id.uuidString,
            domainIdentifier: "com.antonnovoselov.VivaDicta",
            attributeSet: transcription.searchableAttributes
        )

        // Set expiration date to 30 days (reduced from 90)
        item.expirationDate = Date().addingTimeInterval(30 * 24 * 60 * 60)

        do {
            let index = CSSearchableIndex.default()
            try await index.indexSearchableItems([item])
            logger.logInfo("[Spotlight] Indexed transcription: \(transcription.id.uuidString)")
        } catch {
            logger.logError("[Spotlight] Failed to index transcription: \(error.localizedDescription)")
        }
    }

    /// Remove a transcription from Spotlight index
    func removeTranscriptionFromSpotlight(_ transcriptionID: UUID) async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.logError("[Spotlight] Indexing is unavailable")
            return
        }

        do {
            let index = CSSearchableIndex.default()
            try await index.deleteSearchableItems(withIdentifiers: [transcriptionID.uuidString])
            logger.logInfo("[Spotlight] Removed transcription from index: \(transcriptionID.uuidString)")
        } catch {
            logger.logError("[Spotlight] Failed to remove transcription: \(error.localizedDescription)")
        }
    }

    // TODO: Add method to update a single transcription in Spotlight when tags are generated
    func updateTranscriptionInSpotlight(_ transcription: Transcription) async {
        // Reindexing with the same identifier will update the existing item
        await indexTranscriptionToSpotlight(transcription)
    }

    // Legacy batch indexing method - kept for manual rebuild if needed
    func updateSpotlightIndex() async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.logError("[Spotlight] Indexing is unavailable")
            return
        }

        let container = Persistence.container

        do {
            // Create a fetch descriptor for non-empty transcriptions
            let descriptor = FetchDescriptor<Transcription>(
                predicate: #Predicate { transcription in
                    transcription.text != "" ||
                    (transcription.enhancedText != nil && transcription.enhancedText != "")
                },
                sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
            )

            let transcriptions = try container.mainContext.fetch(descriptor)

            let searchableItems = transcriptions.map { transcription in
                let item = CSSearchableItem(
                    uniqueIdentifier: transcription.id.uuidString,
                    domainIdentifier: "com.antonnovoselov.VivaDicta",
                    attributeSet: transcription.searchableAttributes
                )

                return item
            }

            // Add the transcriptions to the search index so people can find them through Spotlight.
            let index = CSSearchableIndex.default()
            try await index.indexSearchableItems(searchableItems)
            logger.logInfo("[Spotlight] Successfully indexed \(searchableItems.count) transcriptions")
        } catch {
            logger.logError("[Spotlight] Failed to index transcriptions. Reason: \(error.localizedDescription)")
        }
    }
    
    
    func userActivity(for transcription: Transcription) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.antonnovoselov.VivaDicta.viewTranscription")

        // Use the same attribute set we use for Spotlight
        let attributes = transcription.searchableAttributes

        activity.title = attributes.title
        activity.userInfo = ["id": transcription.id.uuidString]
        activity.persistentIdentifier = transcription.id.uuidString
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true

        // Use keywords from the searchable attributes
        if let keywords = attributes.keywords {
            activity.keywords = Set(keywords)
        }

        // Reuse the same content attribute set for consistency
        activity.contentAttributeSet = attributes

        return activity
    }
}
