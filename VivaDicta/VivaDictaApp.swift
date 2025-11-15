//
//  VivaDictaApp.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI
import SwiftData
import os

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

        // Reset session state on app launch to prevent stale state issues
        AppGroupCoordinator.shared.resetSessionStateOnAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState)
                .onAppear {
                    // Set the AppState reference for quick actions
#if !os(macOS)
                    SceneDelegate.appState = appState
#endif
                }
                .onOpenURL { url in
                    handleDeepLink(url)
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
            
            //            appState.startLiveActivity()
            
            
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
}



enum QuickActionType: String {
    case startRecord
}
