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
import TipKit

@main
struct VivaDictaApp: App {
#if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    
    @State private var dataController: DataController
    @State private var modelContainer: ModelContainer
    @State private var router: Router
    
    @State var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(UserDefaultsStorage.Keys.hasCompletedOnboarding, store: UserDefaultsStorage.appPrivate)
    private var hasCompletedOnboarding = false
    
    private let logger = Logger(category: .app)
    
    // Thread-safe flag for keyboard request processing
    //    private static let processingQueue = DispatchQueue(label: "com.vivadicta.keyboardProcessing")
    //    private static var isProcessingKeyboardRequest = false
    
    init() {
        // Register UserDefaults defaults for settings that should default to true
        
        UserDefaultsStorage.shared.register(defaults: [
            AppGroupCoordinator.isHapticsEnabled: true
        ])
//        UserDefaultsStorage.shared.synchronize()
//
//        UserDefaults.standard.register(defaults: [
//            UserDefaultsStorage.Keys.isHapticsEnabled: true
//        ])

        // Initialize Persistence
        let modelContainer: ModelContainer
        
        do {
            let sharedStoreURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupCoordinator.shared.appGroupId)!.appendingPathComponent("VivaDicta.sqlite")
            let config = ModelConfiguration(url: sharedStoreURL)
            modelContainer = try ModelContainer(for: Transcription.self, configurations: config)
        } catch {
            print("Error loading ModelContainer; switching to in-memory storage.")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(for: Transcription.self, configurations: config)
        }
        
        self._modelContainer = .init(initialValue: modelContainer)
        
        let dataController = DataController(modelContainer: modelContainer)
        self._dataController = .init(initialValue: dataController)
        
        let router = Router()
        self._router = .init(initialValue: router)
        
        AppDependencyManager.shared.add(dependency: dataController)
        AppDependencyManager.shared.add(dependency: router)
        
        self._appState = State(initialValue: AppState(modelContainer: modelContainer))
        
        // Initialize app directories
        FileManager.createAppDirectories()
        
        // Check if user tapped "Open Settings" in onboarding before app was terminated
        // This handles the case where app terminates when enabling Full Access
        if UserDefaultsStorage.appPrivate.bool(forKey: UserDefaultsStorage.Keys.didTapOpenSettingsInOnboarding) {
            UserDefaultsStorage.appPrivate.set(true, forKey: UserDefaultsStorage.Keys.hasCompletedOnboarding)
            UserDefaultsStorage.appPrivate.removeObject(forKey: UserDefaultsStorage.Keys.didTapOpenSettingsInOnboarding)
        }
        
        // Clean up any stuck Live Activities from previous session on cold start
        Task {
            let activityCount = Activity<VivaDictaLiveActivityAttributes>.activities.count
            for activity in Activity<VivaDictaLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            if activityCount > 0 {
                let cleanupLogger = Logger(category: .app)
                cleanupLogger.logInfo("🧹 Cleaned up \(activityCount) stuck Live Activities on cold start")
            }
        }
        
        // Reset session state on app launch to prevent stale state issues
        AppGroupCoordinator.shared.resetSessionStateOnAppLaunch()
        
        ShortcutsProvider.updateAppShortcutParameters()
        IntentDonationManager.shared.donate(intent: ToggleRecordIntent())
        
        // TODO: - It's not working, keeping for reference. It was presumed to work with ToggleKeyboardFlowIntent.
        // Set up handler for keyboard session activation from intent
        AppGroupCoordinator.shared.onKeyboardSessionActivated = {
            let logger = Logger(category: .app)
            logger.logInfo("🎙️ Keyboard session activated - starting prewarm")
            
            // Start audio prewarm session when keyboard session is activated
            Task {
                do {
                    try await AudioPrewarmManager.shared.startPrewarmSession()
                    logger.logInfo("🎙️ Hot Mic activated from keyboard session")
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
                }
            }
        }
        
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainView()
                    .task {
                        //                        try? Tips.resetDatastore()
                        
                        try? Tips.configure([
                            //                            .displayFrequency(.immediate),
                            .datastoreLocation(.applicationDefault)])
                    }
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
                    .environment(appState)
                    .environment(router)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .onContinueUserActivity("com.antonnovoselov.VivaDicta.viewTranscription") { userActivity in
                        try? handleTranscriptionActivity(userActivity)
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if oldPhase == .active && newPhase == .inactive {
                            appState.showKeyboardFlowSheet = false
                        }
                        
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
            } else {
                OnboardingView {
                    HapticManager.celebration()
                    hasCompletedOnboarding = true
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
    
    private func attemptReturnToHost(hostId: String) {
        // Keyboard session flow:
        // 1. If we CAN return to host app: Start recording → Return to host
        //    User sees recording already happening when they arrive
        // 2. If we CANNOT return: Show keyboard flow sheet → User manually switches
        //    User will manually start recording after switching
        
        logger.logInfo("🔄 attemptReturnToHost called with hostId: \(hostId)")
        logger.logInfo("🔄 Attempting to return to host: \(hostId)")
        
        if let urlScheme = getURLSchemeForBundleId(hostId),
           let url = URL(string: urlScheme) {
            logger.logInfo("🚀 Found URL scheme, attempting to open: \(urlScheme)")
            
            // Check if we can open the URL before starting recording
            Task { @MainActor in
                if UIApplication.shared.canOpenURL(url) {
                    // We can return to host - start actual recording first
                    logger.logInfo("🎙️ Starting recording before returning to host app")
                    
                    // Check if we have a transcription model selected
                    guard let vm = appState.recordViewModel else {
                        logger.logError("❌ RecordViewModel not available")
                        appState.showKeyboardFlowSheet = true
                        return
                    }
                    
                    if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
                        logger.logWarning("⚠️ No transcription model selected - showing keyboard flow sheet")
                        appState.showKeyboardFlowSheet = true
                        return
                    }
                    
                    // Start the actual recording
                    vm.startCaptureAudio()
                    
                    // Small delay to ensure recording is fully started
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    
                    // Now return to the host app
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            self.logger.logInfo("✅ Successfully opened host app: \(hostId) with recording started")
                        } else {
                            self.logger.logError("❌ Failed to open host app: \(hostId)")
                            // Failed to open - recording is already started, user can continue
                        }
                    }
                } else {
                    logger.logInfo("❌ Cannot open URL scheme: \(urlScheme)")
                    // Can't open URL - don't start recording, show keyboard flow sheet
                    appState.showKeyboardFlowSheet = true
                }
            }
        } else {
            logger.logInfo("❌ No URL scheme available for host: \(hostId)")
            // No URL scheme found - show the keyboard flow sheet as fallback
            appState.showKeyboardFlowSheet = true
            
            // TODO: Log to Firebase Analytics when we show keyboard flow sheet due to missing URL scheme mapping
            // This helps us track which apps users are trying to use but we don't have URL schemes for yet
            // We can then add popular apps to the knownSchemes dictionary
            // Bundle ID to log: \(hostId)
            // Linear issue: https://linear.app/antonnovoselov/issue/VIV-175/firebase-analytics-add-logging-what-app-was-not-added-to-predefined
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        logger.logInfo("📱 Received deep link: \(url.absoluteString)")
        
        // Handle deep links from keyboard extension
        if url.absoluteString.starts(with: "vivadicta://record-for-keyboard") {
            logger.logInfo("📱 Recognized as keyboard recording request")
            
            // Thread-safe check to prevent multiple simultaneous processing
            //            var shouldProcess = false
            //            Self.processingQueue.sync {
            //                if !Self.isProcessingKeyboardRequest {
            //                    Self.isProcessingKeyboardRequest = true
            //                    shouldProcess = true
            //                }
            //            }
            
            //            guard shouldProcess else {
            //                logger.logInfo("⚠️ Already processing keyboard request, ignoring duplicate call")
            //                return
            //            }
            
            logger.logInfo("🔒 Processing keyboard request (thread-safe)")
            
            // Ensure we reset the flag when done
            //            defer {
            //                Self.processingQueue.sync {
            //                    Self.isProcessingKeyboardRequest = false
            //                }
            //                logger.logInfo("🔓 Keyboard request processing completed")
            //            }
            
            
            
            appState.startLiveActivity()
            
            // Start audio prewarm session and wait for it to be ready before recording
            Task { @MainActor in
                do {
                    // Start and await prewarm session to ensure it's fully ready
                    try await AudioPrewarmManager.shared.startPrewarmSession()
                    logger.logInfo("🎙️ Prewarm session fully ready")
                    
                    // Extract hostId from URL query parameters
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let hostId = components?.queryItems?.first(where: { $0.name == "hostId" })?.value
                    
                    // Activate keyboard session to notify keyboard that hot mic is ready
                    let timeoutSeconds = AudioPrewarmManager.shared.audioSessionTimeout
                    AppGroupCoordinator.shared.activateKeyboardSession(
                        timeoutSeconds: timeoutSeconds
                    )
                    
                    logger.logInfo("🎙️ Hot Mic and keyboard session activated from deeplink")
                    
                    // Now that prewarm is ready, attempt to return to host and start recording
                    if let hostId = hostId {
                        attemptReturnToHost(hostId: hostId)
                    } else {
                        // No host ID available, show the keyboard flow sheet as fallback
                        appState.showKeyboardFlowSheet = true
                    }
                    
                    
                    
                    
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
                    // If prewarm fails, still try to show keyboard flow sheet as fallback
                    appState.showKeyboardFlowSheet = true
                }
            }
        } else if url.absoluteString == "startRecordFromWidget" {
            logger.logInfo("📱 Recognized as widget recording request")

            // Start recording
            appState.shouldStartRecording = true
            logger.logInfo("🎙️ Starting recording from widget deeplink")
        } else if url.absoluteString.starts(with: "vivadicta://transcribe-shared") {
            logger.logInfo("📱 Recognized as share extension transcription request")

            // Handle shared audio from Share Extension
            appState.shouldTranscribeSharedAudio = true
            logger.logInfo("🎵 Will transcribe shared audio file")
        } else {
            logger.logWarning("📱 Unknown deep link URL: \(url.absoluteString)")
        }
    }
    
    
    private func getURLSchemeForBundleId(_ bundleId: String) -> String? {
        // Map of common apps and their URL schemes
        // Note: This is not comprehensive and many apps don't have public URL schemes
        let knownSchemes: [String: String] = [
            "com.apple.mobilenotes": "mobilenotes://",
            "com.apple.MobileSMS": "sms://",
            "com.apple.mobilemail": "message://",
            "com.apple.mobilesafari": "x-web-search://",
            "com.microsoft.Office.Word": "ms-word://",
            "com.culturedcode.ThingsiPhone": "things://",
            "com.google.Gmail": "googlegmail://",
            "com.facebook.Facebook": "fb://",
            "com.facebook.Messenger": "fb-messenger://",
            "com.atebits.Tweetie2": "twitter://",
            "com.toyopagroup.picaboo": "snapchat://",
            "com.burbn.instagram": "instagram://",
            "net.whatsapp.WhatsApp": "whatsapp-consumer://",
            "net.whatsapp.WhatsAppSMB": "whatsapp://",
            "com.telegram.telegram-ios": "tg://",
            "ph.telegra.Telegraph": "tg://",
            "com.viber": "viber://",
            "com.spotify.client": "spotify://",
            "com.apple.Pages": "pages://",
            "com.apple.Numbers": "numbers://",
            "com.apple.Keynote": "keynote://",
            "com.google.chrome.ios": "googlechrome://",
            "com.microsoft.Office.Outlook": "ms-outlook://",
            "com.getdropbox.Dropbox": "dbapi-1://",
            "com.google.Translate": "googletranslate://",
            "com.linkedin.LinkedIn": "linkedin://",
            "com.openai.chat": "com.openai.chat://",
            "ai.perplexity.app": "perplexity-app://",
            "com.anthropic.claude": "claude://",
            "md.obsidian": "obsidian://"
            // Add more as needed
        ]
        
        return knownSchemes[bundleId]
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
    
    @MainActor
    private func handleTranscriptionActivity(_ userActivity: NSUserActivity) throws {
        logger.logInfo("📱 Handling transcription view activity (Handoff/Siri)")
        
        // Try to get the transcription ID from userInfo
        if let transcriptionIDString = userActivity.userInfo?["id"] as? String,
           let transcriptionID = UUID(uuidString: transcriptionIDString) {
            if let transcription = try dataController.transcription(byId: transcriptionID) {
                router.select(transcription: transcription)
            }
            logger.logInfo("📱 Opening transcription from user activity: \(transcriptionID)")
        } else {
            logger.logError("📱 Failed to get transcription ID from user activity")
        }
    }
}



enum QuickActionType: String {
    case startRecord
}
