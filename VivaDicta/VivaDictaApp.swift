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
    @State var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "VivaDictaApp")

    init() {
        // Initialize app directories
        FileManager.createAppDirectories()
    }

    var body: some Scene {
        WindowGroup {
            TabBarView(appState: appState)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        logger.info("🎬 App became active - checking for stale Live Activity")
                        appState.checkAndEndStaleLiveActivity()
                    case .inactive:
                        logger.info("🎬 App became inactive")
                    case .background:
                        logger.info("🎬 App went to background")
                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(Persistence.container)
    }
    
    
    private func handleDeepLink(_ url: URL) {
        logger.info("📱 Received deep link: \(url.absoluteString)")

        // Handle deep links from keyboard extension
        if url.absoluteString == "vivadicta://record-for-keyboard" {
            logger.info("📱 Recognized as keyboard recording request")
            
//            appState.startLiveActivity()
            

            // Start audio prewarm session to keep app alive in background
            do {
                try AudioSessionManager.shared.startHotMicSession(timeoutSeconds: 180)
//                try AudioPrewarmManager.shared.startPrewarmSession()
//                logger.info("🎙️ Audio prewarm session started from deeplink")
                
                logger.info("🎙️ Hot Mic started from deeplink")

            } catch {
                logger.error("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
            }

        } else {
            logger.warning("📱 Unknown deep link URL: \(url.absoluteString)")
        }
    }
}
