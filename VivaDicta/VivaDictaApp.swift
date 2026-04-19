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
import FirebaseAnalytics

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

    init() {
        // Track app launch count for analytics and feature gating
        AppLaunchTracker.recordLaunch()

        // Register UserDefaults defaults for settings that should default to true

        UserDefaultsStorage.shared.register(defaults: [
            AppGroupCoordinator.isHapticsEnabled: true
        ])
        UserDefaults.standard.register(defaults: [
            UserDefaultsStorage.Keys.isICloudSyncEnabled: true
        ])

        // Initialize Persistence
        let modelContainer: ModelContainer
        let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupCoordinator.shared.appGroupId)!
        let isICloudSyncEnabled = UserDefaults.standard.bool(forKey: UserDefaultsStorage.Keys.isICloudSyncEnabled)

        do {
            let sharedStoreURL = appGroupURL.appendingPathComponent("VivaDicta.sqlite")
            let config = ModelConfiguration(
                url: sharedStoreURL,
                cloudKitDatabase: isICloudSyncEnabled
                    ? .private("iCloud.com.antonnovoselov.VivaDicta")
                    : .none
            )
            modelContainer = try ModelContainer(
                for: Transcription.self, VocabularyWord.self, WordReplacement.self, TranscriptionVariation.self, ExtractedReminderDraft.self, CustomRewritePreset.self, RewritePreset.self, TranscriptionTag.self, TranscriptionTagAssignment.self, ChatMessage.self, ChatConversation.self, MultiNoteConversation.self, SmartSearchConversation.self,
                configurations: config
            )
        } catch {
            logger.logError("Error loading ModelContainer; switching to in-memory storage. \(error.localizedDescription)")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(
                for: Transcription.self, VocabularyWord.self, WordReplacement.self, TranscriptionVariation.self, ExtractedReminderDraft.self, CustomRewritePreset.self, RewritePreset.self, TranscriptionTag.self, TranscriptionTagAssignment.self, ChatMessage.self, ChatConversation.self, MultiNoteConversation.self, SmartSearchConversation.self,
                configurations: config
            )
        }
        
        self._modelContainer = .init(initialValue: modelContainer)

        // Set static model container references for services that use SwiftData lookups
        CustomVocabulary.modelContainer = modelContainer
        ReplacementsService.modelContainer = modelContainer

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
            // Stamp latest release ID so What's New doesn't show for fresh installs
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            if let release = WhatsNewCatalog.release(for: currentVersion) {
                UserDefaultsStorage.appPrivate.set(release.id, forKey: UserDefaultsStorage.Keys.lastSeenWhatsNewVersion)
            }
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
                        try? Tips.configure([
                            .datastoreLocation(.applicationDefault)])
                    }
                    .onAppear {
                        NotesSearchToolRuntime.modelContainer = modelContainer

                        // Set the AppState reference for quick actions
#if !os(macOS)
                        SceneDelegate.appState = appState
#endif

                        // Migrate dictionary data from UserDefaults to SwiftData (one-time)
                        DictionaryMigrationService.shared.migrateIfNeeded(context: modelContainer.mainContext)

                        // Migrate API keys from UserDefaults to Keychain for iCloud sync (one-time)
                        APIKeyMigrationService.shared.migrateIfNeeded()


                        if SmartSearchFeature.isEnabled {
                            // Index all transcriptions for RAG Smart Search
                            Task {
                                await RAGIndexingService.shared.indexAllIfNeeded(modelContext: modelContainer.mainContext)
                            }
                        }

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
                        
                        // Set up handler for AI processing
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
                            appState.showKeyboardFlowToast = false
                        }
                        
                        switch newPhase {
                        case .active:
                            logger.logInfo("🎬 App became active - checking for stale Live Activity")
                            appState.checkAndEndStaleLiveActivity()
                            RecentNotesCache.syncFromDatabase(modelContext: modelContainer.mainContext)
                        case .inactive:
                            logger.logInfo("🎬 App became inactive")
                        case .background:
                            logger.logInfo("🎬 App went to background")
                            updateShortcutItems()
                            RecentNotesCache.syncFromDatabase(modelContext: modelContainer.mainContext)
                        @unknown default:
                            break
                        }
                    }
            } else {
                OnboardingView {
                    HapticManager.celebration()
                    hasCompletedOnboarding = true
                    // Stamp latest release ID so What's New doesn't show for fresh installs
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    if let release = WhatsNewCatalog.release(for: currentVersion) {
                        UserDefaultsStorage.appPrivate.set(release.id, forKey: UserDefaultsStorage.Keys.lastSeenWhatsNewVersion)
                    }
                    Analytics.logEvent("onboarding_completed", parameters: nil)
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
    
    private func attemptReturnToHost(hostId: String) {
        // Keyboard session flow:
        // 1. If we CAN return to host app: Start recording → Return to host
        //    User sees recording already happening when they arrive
        // 2. If we CANNOT return: Start recording → Show toast → User manually switches
        //    User sees recording already happening when they arrive
        
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
                        appState.showKeyboardFlowToast = true
                        return
                    }
                    
                    if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
                        logger.logWarning("⚠️ No transcription model selected - showing keyboard flow toast")
                        appState.showKeyboardFlowToast = true
                        return
                    }
                    
                    // Start the actual recording
                    vm.startCaptureAudio(sourceTag: SourceTag.keyboard)
                    
                    // Small delay to ensure recording is fully started
                    try? await Task.sleep(for: .milliseconds(200))
                    
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
                    // Can't open URL - don't start recording, show keyboard flow toast
                    appState.showKeyboardFlowToast = true
                }
            }
        } else {
            logger.logInfo("❌ No URL scheme available for host: \(hostId)")
            // No URL scheme found - start recording and show keyboard flow toast
            // so user can switch back manually and find recording already in progress
            Task { @MainActor in
                if let vm = appState.recordViewModel,
                   vm.transcriptionManager.getCurrentTranscriptionModel() != nil {
                    logger.logInfo("🎙️ Starting recording before showing manual switch sheet")
                    vm.startCaptureAudio(sourceTag: SourceTag.keyboard)
                }
                appState.showKeyboardFlowToast = true
            }

            // Known system services that have no URL scheme - don't log as unrecognized
            let knownNoSchemeHosts: Set<String> = [
                "com.apple.SafariViewService",  // SFSafariViewController in-app browser
                "com.apple.springboard",        // iOS home screen
                "com.apple.Spotlight",          // Spotlight search
                "com.apple.journal",            // Apple Journal
                "com.apple.AppleMediaServicesUI.ComposeReviewExtension", // App Store review
                "com.antonnovoselov.VivaDicta", // Own app
                "com.dmitrii.medvedev.gptalk",  // GPChat/Xenova AI - no known URL scheme
                "com.saner.ai",                 // Saner AI - no known URL scheme
                "dk.FirstForm.SnappyNotesiOS",  // Snappy Notes - no known URL scheme
                "com.ai.venice",                // Venice AI - no known URL scheme
                "com.replay.Echo",              // Echo by Replay - no known URL scheme
                "com.avast.ios.security",       // Avast Security - no known URL scheme
                "com.elaborapp.NoteBox",        // NoteBox - no known URL scheme
                "com.ios.aquaMagic062516.cn",   // Unknown app
                "com.lixkit.diary",             // Diary app - no known URL scheme
                "com.weichart.Zettel",          // Zettel Notes - no known URL scheme
                "h3p.Neon-Vision-Editor",       // Neon Vision Editor - no known URL scheme
                "mystxtalk",                    // Unknown messaging app
                "ru.ozon.sellerApp"             // Ozon Seller - no known URL scheme
            ]

            if !knownNoSchemeHosts.contains(hostId) {
                // Log unrecognized host app to Firebase Analytics
                // This helps track which apps users are trying to use but we don't have URL schemes for yet
                Analytics.logEvent("unrecognized_host_app", parameters: [
                    "bundle_id": hostId
                ])
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        logger.logInfo("📱 Received deep link: \(url.absoluteString)")

        // Handle audio files opened via "Open With" from Files app
        if url.isFileURL {
            handleOpenWithAudioFile(url)
            return
        }

        // Handle universal links from vivadicta.com
        if url.host == "vivadicta.com" || url.host == "www.vivadicta.com" {
            logger.logInfo("🔗 Universal link opened: \(url.absoluteString)")
            logger.logInfo("🔗 Path: \(url.path)")
            // App opened via universal link - currently just opens to main screen
            return
        }

        // Handle deep links from keyboard extension
        if url.absoluteString.starts(with: "vivadicta://record-for-keyboard") {
            logger.logInfo("📱 Recognized as keyboard recording request")

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

                    // Log keyboard session start to Firebase Analytics
                    Analytics.logEvent("keyboard_session_started", parameters: [
                        "host_bundle_id": hostId ?? "unknown"
                    ])

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
                        // No host ID available (e.g. iOS 26.4 broke hostApplicationBundleId)
                        // Start recording and show toast so user can manually switch back
                        if let vm = appState.recordViewModel,
                           vm.transcriptionManager.getCurrentTranscriptionModel() != nil {
                            logger.logInfo("🎙️ Starting recording before showing manual switch toast (no hostId)")
                            vm.startCaptureAudio(sourceTag: SourceTag.keyboard)
                        }
                        appState.showKeyboardFlowToast = true
                    }
                    
                    
                    
                    
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
                    // If prewarm fails, still try to show keyboard flow toast as fallback
                    appState.showKeyboardFlowToast = true
                }
            }
        } else if url.absoluteString.starts(with: "vivadicta://activate-for-keyboard") {
            logger.logInfo("📱 Recognized as keyboard session activation request (text processing)")

            Task { @MainActor in
                do {
                    try await AudioPrewarmManager.shared.startPrewarmSession()
                    logger.logInfo("🎙️ Prewarm session ready for text processing")

                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let hostId = components?.queryItems?.first(where: { $0.name == "hostId" })?.value

                    let timeoutSeconds = AudioPrewarmManager.shared.audioSessionTimeout
                    AppGroupCoordinator.shared.activateKeyboardSession(
                        timeoutSeconds: timeoutSeconds
                    )

                    logger.logInfo("🎙️ Keyboard session activated for text processing")

                    // Return to host app without starting recording
                    if let hostId = hostId {
                        returnToHost(hostId: hostId)
                    } else {
                        appState.showKeyboardFlowToast = true
                    }
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session for text processing: \(error.localizedDescription)")
                    appState.showKeyboardFlowToast = true
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
    
    
    private func handleOpenWithAudioFile(_ url: URL) {
        logger.logInfo("📂 Received audio file via Open With: \(url.lastPathComponent)")

        guard url.startAccessingSecurityScopedResource() else {
            logger.logError("❌ Failed to access security-scoped resource")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        let audioDirectory = FileManager.appDirectory(for: .audio)
        let fileExtension = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
        let destinationURL = audioDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            logger.logInfo("📂 Copied audio file to: \(destinationURL.lastPathComponent)")
            appState.openedAudioFileURL = destinationURL
        } catch {
            logger.logError("❌ Failed to copy opened audio file: \(error.localizedDescription)")
        }
    }

    /// Returns to the host app without starting recording.
    /// Used by the text processing keyboard flow.
    private func returnToHost(hostId: String) {
        logger.logInfo("🔄 Returning to host app (no recording): \(hostId)")

        if let urlScheme = getURLSchemeForBundleId(hostId),
           let url = URL(string: urlScheme) {
            Task { @MainActor in
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            self.logger.logInfo("✅ Returned to host app: \(hostId)")
                        } else {
                            self.logger.logError("❌ Failed to open host app: \(hostId)")
                        }
                    }
                } else {
                    logger.logInfo("❌ Cannot open URL scheme: \(urlScheme)")
                    appState.showKeyboardFlowToast = true
                }
            }
        } else {
            logger.logInfo("❌ No URL scheme for host: \(hostId)")
            appState.showKeyboardFlowToast = true
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
            "md.obsidian": "obsidian://",
            "im.monica.app.monica": "monica://",
            "com.mem-labs.mem": "mem://",
            "com.google.OPA": "google://",
            "com.cardify.tinder": "tinder://",
            "com.readdle.smartemail": "readdle-spark://",
            "com.hammerandchisel.discord": "discord://",
            "com.google.GoogleMobile": "googlemobileapp://",
            "org.whispersystems.signal": "sgnl://",
            "co.fluder.mobile.FSNotes-iOS": "fsnotes://",
            "ch.threema.iapp": "threema://",
            "com.burbn.barcelona": "barcelona://",
            "com.briansunter.logseq-dev": "logseq://",
            "com.github.stormbreaker.prod": "github://",
            "ai.x.GrokApp": "grok://",
            "com.appliedphasor.secure-shellfish": "shellfish://",
            "com.crystalnix.ServerAuditor": "termius://",
            "com.microsoft.skype.teams": "msteams://",
            "com.reddit.Reddit": "reddit://",
            "pro.writer": "ia-writer://",
            "com.google.gemini": "gemini-app://",
            "ru.yandex.mobile.translate": "yandextranslate://"
        ]
        
        return knownSchemes[bundleId]
    }
    
    func updateShortcutItems() {
        var items: [UIApplicationShortcutItem] = []

        if let continueAction = mostRecentChatShortcut(modelContext: modelContainer.mainContext) {
            items.append(continueAction)
        }

        items.append(UIApplicationShortcutItem(
            type: QuickActionType.search.rawValue,
            localizedTitle: "Search",
            localizedSubtitle: "Find notes instantly",
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
            userInfo: [:]))
        items.append(UIApplicationShortcutItem(
            type: QuickActionType.askAI.rawValue,
            localizedTitle: "Ask AI",
            localizedSubtitle: "Chat with your notes",
            icon: UIApplicationShortcutIcon(systemImageName: "bubble.left.and.bubble.right.fill"),
            userInfo: [:]))
        items.append(UIApplicationShortcutItem(
            type: QuickActionType.startRecord.rawValue,
            localizedTitle: "Record",
            localizedSubtitle: "Turn your voice into text",
            icon: UIApplicationShortcutIcon(systemImageName: "microphone.circle.fill"),
            userInfo: [:]))

        UIApplication.shared.shortcutItems = items
    }

    @MainActor
    private func mostRecentChatShortcut(modelContext: ModelContext) -> UIApplicationShortcutItem? {
        var multiDescriptor = FetchDescriptor<MultiNoteConversation>(
            sortBy: [SortDescriptor(\.lastInteractionAt, order: .reverse)]
        )
        multiDescriptor.fetchLimit = 1
        let latestMulti = (try? modelContext.fetch(multiDescriptor))?.first

        let singleDescriptor = FetchDescriptor<ChatConversation>(
            sortBy: [SortDescriptor(\.lastInteractionAt, order: .reverse)]
        )
        let latestSingle = (try? modelContext.fetch(singleDescriptor))?.first { conversation in
            conversation.transcription != nil && !(conversation.messages ?? []).isEmpty
        }

        switch (latestMulti, latestSingle) {
        case (let multi?, let single?):
            return multi.lastInteractionAt >= single.lastInteractionAt
                ? continueChatItem(for: multi)
                : continueChatItem(for: single)
        case (let multi?, nil):
            return continueChatItem(for: multi)
        case (nil, let single?):
            return continueChatItem(for: single)
        case (nil, nil):
            return nil
        }
    }

    private func continueChatItem(for conversation: MultiNoteConversation) -> UIApplicationShortcutItem {
        let subtitle = conversation.title.isEmpty ? "Untitled chat" : conversation.title
        let kind: PendingChatKind = conversation.isAllNotes ? .allNotes : .multiNote
        return UIApplicationShortcutItem(
            type: QuickActionType.continueChat.rawValue,
            localizedTitle: "Continue chat",
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(systemImageName: "bubble.left.fill"),
            userInfo: [
                "chatID": conversation.id.uuidString as NSString,
                "chatKind": kind.rawValue as NSString
            ])
    }

    private func continueChatItem(for conversation: ChatConversation) -> UIApplicationShortcutItem {
        let snippet: String
        if let transcription = conversation.transcription {
            let trimmed = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            snippet = trimmed.isEmpty ? "Note chat" : String(trimmed.prefix(60))
        } else {
            snippet = "Note chat"
        }
        return UIApplicationShortcutItem(
            type: QuickActionType.continueChat.rawValue,
            localizedTitle: "Continue chat",
            localizedSubtitle: snippet,
            icon: UIApplicationShortcutIcon(systemImageName: "bubble.left.fill"),
            userInfo: [
                "chatID": conversation.id.uuidString as NSString,
                "chatKind": PendingChatKind.singleNote.rawValue as NSString
            ])
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
    case search
    case askAI
    case continueChat
}
