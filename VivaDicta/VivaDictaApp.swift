//
//  VivaDictaApp.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI
import SwiftData
import os
import AppIntents
import CoreSpotlight
import ActivityKit

@main
struct VivaDictaApp: App {
#if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    
    @State var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "VivaDictaApp")

    init() {
        // Initialize app directories
        FileManager.createAppDirectories()

        // Clean up any stuck Live Activities from previous session on cold start
        Task {
            let activityCount = Activity<VivaDictaLiveActivityAttributes>.activities.count
            for activity in Activity<VivaDictaLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if activityCount > 0 {
                let cleanupLogger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "VivaDictaApp")
                cleanupLogger.logInfo("🧹 Cleaned up \(activityCount) stuck Live Activities on cold start")
            }
        }

        // Reset session state on app launch to prevent stale state issues
        AppGroupCoordinator.shared.resetSessionStateOnAppLaunch()

        ShortcutsProvider.updateAppShortcutParameters()

        // TODO: - It's not working, keeping for reference. It was presumed to work with ToggleKeyboardFlowIntent.
        // Set up handler for keyboard session activation from intent
        AppGroupCoordinator.shared.onKeyboardSessionActivated = {
            let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "VivaDictaApp")
            logger.logInfo("🎙️ Keyboard session activated - starting prewarm")

            // Start audio prewarm session when keyboard session is activated
            do {
                try AudioPrewarmManager.shared.startPrewarmSession()
                logger.logInfo("🎙️ Hot Mic activated from keyboard session")
            } catch {
                logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
            }
        }

    }

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState)
                .onAppear {
                    // Set the AppState reference for quick actions
#if !os(macOS)
                    SceneDelegate.appState = appState
#endif

                    // Set up handler for session termination from Live Activity
                    AppGroupCoordinator.shared.onTerminateSessionFromLiveActivity = {
                        logger.logInfo("🔴 Session termination requested from Live Activity")

                        // End audio prewarm session
                        AudioPrewarmManager.shared.endSession()

                        // End Live Activity
                        Task { @MainActor in
                            await appState.endLiveActivity()
                        }

                        logger.logInfo("🔴 Terminated audio session and Live Activity")
                    }

                    // Set up handler for keyboard session expiration (timeout)
                    AppGroupCoordinator.shared.onKeyboardSessionExpired = {
                        logger.logInfo("⏰ Keyboard session expired - cleaning up Live Activity")

                        // End Live Activity when session times out
                        Task { @MainActor in
                            await appState.endLiveActivity()
                        }
                    }

                    // Set up handler for recording state changes
                    AppGroupCoordinator.shared.onRecordingStateChanged = { isRecording in
                        Task { @MainActor in
                            if isRecording {
                                await appState.updateLiveActivityState(.recording)
                            } else {
                                await appState.updateLiveActivityState(.idle)
                            }
                        }
                    }

                    // Set up handler for transcription processing
                    AppGroupCoordinator.shared.onTranscriptionTranscribing = {
                        Task { @MainActor in
                            await appState.updateLiveActivityState(.transcribing)
                        }
                    }

                    // Set up handler for AI enhancement
                    AppGroupCoordinator.shared.onTranscriptionEnhancing = {
                        Task { @MainActor in
                            await appState.updateLiveActivityState(.enhancing)
                        }
                    }

                    // Set up handler for transcription completion - return to idle
                    AppGroupCoordinator.shared.onTranscriptionCompleted = { _ in
                        Task { @MainActor in
                            await appState.updateLiveActivityState(.idle)
                        }
                    }

                    // Set up handler for transcription error - return to idle
                    AppGroupCoordinator.shared.onTranscriptionError = {
                        Task { @MainActor in
                            await appState.updateLiveActivityState(.idle)
                        }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    handleSpotlightSearch(userActivity)
                }
                .onContinueUserActivity("com.antonnovoselov.VivaDicta.viewTranscription") { userActivity in
                    handleTranscriptionActivity(userActivity)
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        logger.logInfo("🎬 App became active - checking for stale Live Activity")
                        appState.checkAndEndStaleLiveActivity()
                    case .inactive:
                        logger.logInfo("🎬 App became inactive")
                    case .background:
                        logger.logInfo("🎬 App went to background")
                        updateShortcutItems()
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(Persistence.container)
    }
    

    private func handleDeepLink(_ url: URL) {
        logger.logInfo("📱 Received deep link: \(url.absoluteString)")

        // Handle deep links from keyboard extension
        if url.absoluteString == "vivadicta://record-for-keyboard" {
            logger.logInfo("📱 Recognized as keyboard recording request")

            appState.startLiveActivity()

            // Show the keyboard flow sheet
            appState.showKeyboardFlowSheet = true

            // Start audio prewarm session to keep app alive in background
            do {
                //                try AudioSessionManager.shared.startHotMicSession(timeoutSeconds: 180)
                try AudioPrewarmManager.shared.startPrewarmSession()

                // Activate keyboard session to notify keyboard that hot mic is ready
                AppGroupCoordinator.shared.activateKeyboardSession(
                    timeoutSeconds: AudioPrewarmManager.shared.audioSessionTimeout
                )

                logger.logInfo("🎙️ Hot Mic and keyboard session activated from deeplink")

            } catch {
                logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
            }
        } else if url.absoluteString == "startRecordFromWidget" {
            logger.logInfo("📱 Recognized as widget recording request")

            // Start recording
            appState.shouldStartRecording = true
            logger.logInfo("🎙️ Starting recording from widget deeplink")
        } else {
            logger.logWarning("📱 Unknown deep link URL: \(url.absoluteString)")
        }
    }
    
    
    func updateShortcutItems() {
        let recordAction = UIApplicationShortcutItem(
            type: QuickActionType.startRecord.rawValue,
            localizedTitle: "Start Record",
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "microphone.circle.fill"),
            userInfo: [:])
        UIApplication.shared.shortcutItems = [recordAction]
    }

    private func handleSpotlightSearch(_ userActivity: NSUserActivity) {
        logger.logInfo("🔍 Handling Spotlight search activity")

        guard let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            logger.logError("🔍 No unique identifier found in Spotlight activity")
            return
        }

        logger.logInfo("🔍 Spotlight item identifier: \(uniqueIdentifier)")

        // Convert string identifier to UUID
        if let transcriptionID = UUID(uuidString: uniqueIdentifier) {
            appState.selectedTranscriptionID = transcriptionID
            logger.logInfo("🔍 Set selected transcription ID: \(transcriptionID)")
        } else {
            logger.logError("🔍 Failed to parse UUID from identifier: \(uniqueIdentifier)")
        }
    }

    private func handleTranscriptionActivity(_ userActivity: NSUserActivity) {
        logger.logInfo("📱 Handling transcription view activity (Handoff/Siri)")

        // Try to get the transcription ID from userInfo
        if let transcriptionIDString = userActivity.userInfo?["id"] as? String,
           let transcriptionID = UUID(uuidString: transcriptionIDString) {
            appState.selectedTranscriptionID = transcriptionID
            logger.logInfo("📱 Opening transcription from user activity: \(transcriptionID)")
        } else {
            logger.logError("📱 Failed to get transcription ID from user activity")
        }
    }
}



enum QuickActionType: String {
    case startRecord
}
