//
//  AppState.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.12
//  Test change for PR validation
//

import Foundation
import SwiftUI
@preconcurrency import ActivityKit
import os
import CoreSpotlight
import SwiftData
import AppIntents

/// Central application state manager coordinating all major services.
///
/// `AppState` serves as the root state container for the VivaDicta app, managing
/// the lifecycle of core services and coordinating communication between them.
///
/// ## Overview
///
/// The app state manages:
/// - ``TranscriptionManager``: Audio-to-text transcription
/// - ``AIService``: AI-powered text enhancement
/// - ``RecordViewModel``: Audio recording and playback
/// - ``ModelDownloadManager``: On-device model management
/// - Live Activity management for iOS Dynamic Island
/// - Spotlight indexing for transcriptions
///
/// ## Initialization
///
/// `AppState` requires a `ModelContainer` for SwiftData persistence:
///
/// ```swift
/// let container = try ModelContainer(for: Transcription.self)
/// let appState = AppState(modelContainer: container)
/// ```
///
/// ## Service Coordination
///
/// The app state sets up callbacks between services to maintain consistency:
/// - Mode changes in ``AIService`` propagate to ``TranscriptionManager``
/// - Cloud model updates trigger provider refresh
/// - Model downloads update default mode settings
@Observable
class AppState {
    private let logger = Logger(category: .appState)

    /// The active Live Activity for Dynamic Island display, if any.
    var liveActivity: Activity<VivaDictaLiveActivityAttributes>? = nil
    private var liveActivityTimer: Timer?
    private var liveActivityStartTime: Date?

    /// Manager for coordinating transcription services.
    var transcriptionManager: TranscriptionManager!

    /// Service for AI-powered text enhancement.
    var aiService: AIService!

    /// View model for audio recording functionality.
    var recordViewModel: RecordViewModel!

    /// Manager for downloading and managing on-device models.
    var downloadManager: ModelDownloadManager!

    /// Manager for AI text processing presets.
    var presetManager: PresetManager!

    /// Service for syncing custom presets via CloudKit.
    var presetSyncService: PresetSyncService!

    /// Service for receiving audio files from Apple Watch.
    var watchConnectivityService: PhoneWatchConnectivityService!

    // MARK: - Navigation State

    /// Triggers navigation to the Models screen.
    var shouldNavigateToModels: Bool = false

    /// Triggers navigation to the current mode's settings screen.
    var shouldNavigateToModeSettings: Bool = false

    /// Triggers the start of a new recording.
    var shouldStartRecording: Bool = false

    /// Controls display of the keyboard flow toast.
    var showKeyboardFlowToast: Bool = false

    /// Indicates pending shared audio from the Share Extension.
    var shouldTranscribeSharedAudio: Bool = false

    /// Audio file URL received via "Open With" from Files app.
    var openedAudioFileURL: URL?

    init(modelContainer: ModelContainer) {
        transcriptionManager = TranscriptionManager()
        aiService = AIService()
        presetManager = PresetManager()
        aiService.presetManager = presetManager
        PresetMigrationService.migrateIfNeeded(presetManager: presetManager, aiService: aiService)

        // Set up preset sync service for CloudKit sync
        presetSyncService = PresetSyncService()
        presetSyncService.configure(modelContext: modelContainer.mainContext)
        presetSyncService.migrateOldCustomRewritePresets()
        presetSyncService.migrateExistingCustomPresets(presetManager: presetManager)
        presetSyncService.syncFromCloudKit(presetManager: presetManager)
        presetManager.syncService = presetSyncService

        recordViewModel = RecordViewModel(appState: self, modelContainer: modelContainer)
        downloadManager = ModelDownloadManager()

        // Set up callbacks to coordinate between services
        aiService.onModeChange = { [weak self] newMode in
            self?.handleModeChange(newMode)
        }

        transcriptionManager.onCloudModelsUpdate = { [weak self] in
            self?.handleCloudModelsUpdate()
        }

        downloadManager.onModelDownloaded = { [weak self] model in
            // Update the default mode if it doesn't have a model yet
            if let parakeetModel = model as? ParakeetModel {
                self?.aiService.updateDefaultModeIfNeeded(provider: .parakeet, modelName: parakeetModel.name)
            } else if let whisperKitModel = model as? WhisperKitModel {
                self?.aiService.updateDefaultModeIfNeeded(provider: .whisperKit, modelName: whisperKitModel.name)
            }
        }

        // Initialize TranscriptionManager with the current mode
        transcriptionManager.setCurrentMode(aiService.selectedMode)

        // Preload WhisperKit model if conditions are met
        Task {
            await preloadWhisperKitModelIfNeeded()
        }

        // Note: Spotlight indexing is now done on-demand when transcriptions are created/deleted
        // No longer doing batch indexing on app startup

        // Set up Watch Connectivity to receive audio from Apple Watch
        let container = modelContainer
        watchConnectivityService = PhoneWatchConnectivityService()
        watchConnectivityService.onAudioFileReceived = { [weak self] audioURL, metadata in
            guard let self else { return }
            let context = ModelContext(container)
            self.recordViewModel.transcribingSpeechTask = self.recordViewModel.transcribeSpeechTask(
                recordURL: audioURL,
                modelContext: context,
                sourceTag: metadata.sourceTag
            )
        }
    }

    // This method is called when AIService changes its mode
    public func handleModeChange(_ newMode: VivaMode) {
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
    
    /// Transcribes audio from a file URL using the current mode's settings.
    ///
    /// - Parameter audioURL: The file URL of the audio to transcribe.
    /// - Returns: The transcribed text.
    /// - Throws: Any error from the underlying transcription service.
    func transcribe(audioURL: URL) async throws -> String {
        return try await transcriptionManager.transcribe(audioURL: audioURL)
    }
    
    
    
    func startLiveActivity() {
        guard liveActivity == nil else { return }

        // Cancel any existing timer
        liveActivityTimer?.invalidate()

        let attributes = VivaDictaLiveActivityAttributes(name: "VivaDicta")
        do {
            let activityContent = ActivityContent(
                state: VivaDictaLiveActivityAttributes.ContentState(state: .idle),
                staleDate: nil
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
            staleDate: nil
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
    
    /// Indexes a single transcription in Spotlight for system-wide search.
    ///
    /// - Parameter transcription: The transcription to index.
    func indexTranscriptionToSpotlight(_ transcription: Transcription) async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.logError("[Spotlight] Indexing is unavailable")
            return
        }

        do {
            let index = CSSearchableIndex.default()
            let transcriptionEntity = transcription.entity
            try await index.indexAppEntities([transcriptionEntity])
            logger.logInfo("[Spotlight] Indexed transcription: \(transcription.id.uuidString)")
        } catch {
            logger.logError("[Spotlight] Failed to index transcription: \(error.localizedDescription)")
        }
    }

    /// Index a transcription entity in Spotlight (used from detached tasks to avoid actor isolation issues)
    func indexTranscriptionEntityToSpotlight(_ entity: TranscriptionEntity) async {
        guard CSSearchableIndex.isIndexingAvailable() else {
            logger.logError("[Spotlight] Indexing is unavailable")
            return
        }

        do {
            let index = CSSearchableIndex.default()
            try await index.indexAppEntities([entity])
            logger.logInfo("[Spotlight] Indexed transcription entity: \(entity.id)")
        } catch {
            logger.logError("[Spotlight] Failed to index transcription entity: \(error.localizedDescription)")
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
            try await index.deleteAppEntities(identifiedBy: [transcriptionID], ofType: TranscriptionEntity.self)
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

    /// Update a transcription entity in Spotlight (used from detached tasks to avoid actor isolation issues)
    func updateTranscriptionEntityInSpotlight(_ entity: TranscriptionEntity) async {
        await indexTranscriptionEntityToSpotlight(entity)
    }

    func userActivity(for transcription: Transcription) -> NSUserActivity {
        let activity = NSUserActivity(activityType: "com.antonnovoselov.VivaDicta.viewTranscription")

        // Use the same attribute set we use for Spotlight
        let attributes = transcription.searchableAttributes()

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

#if DEBUG
extension AppState {
    convenience init() {
        let container = try! ModelContainer(
            for: Transcription.self,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        Transcription.mockData.forEach { container.mainContext.insert($0) }
        self.init(modelContainer: container)
    }
}
#endif
