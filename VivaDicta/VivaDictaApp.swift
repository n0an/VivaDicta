//
//  VivaDictaApp.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.08.02
//

import SwiftUI
import Analytics
import AppGroup
import SwiftData
import os
import AppIntents
import CoreSpotlight
import ActivityKit
import TipKit
import Presets

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
        #if DEBUG || QA
        if ProcessInfo.processInfo.arguments.contains("UI-TESTING") {
            UIView.setAnimationsEnabled(false)
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            // Inline the App Group ID so this wipe runs before any
            // AppGroupCoordinator.shared access, which would trigger the
            // singleton's init (registering observers, etc.) before state
            // is cleared.
            let appGroupId = "group.com.antonnovoselov.VivaDicta"
            UserDefaults(suiteName: appGroupId)?
                .removePersistentDomain(forName: appGroupId)
        }
        #endif
        
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
                for: Transcription.self, VocabularyWord.self, WordReplacement.self, TranscriptionVariation.self, ExtractedReminderDraft.self, ExtractedCalendarEventDraft.self, CustomRewritePreset.self, RewritePreset.self, TranscriptionTag.self, TranscriptionTagAssignment.self, ChatMessage.self, ChatConversation.self, MultiNoteConversation.self, SmartSearchConversation.self,
                configurations: config
            )
        } catch {
            logger.logError("Error loading ModelContainer; switching to in-memory storage. \(error.localizedDescription)")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            modelContainer = try! ModelContainer(
                for: Transcription.self, VocabularyWord.self, WordReplacement.self, TranscriptionVariation.self, ExtractedReminderDraft.self, ExtractedCalendarEventDraft.self, CustomRewritePreset.self, RewritePreset.self, TranscriptionTag.self, TranscriptionTagAssignment.self, ChatMessage.self, ChatConversation.self, MultiNoteConversation.self, SmartSearchConversation.self,
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
                        PendingAppIntentAction.shared.drain()
#endif

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
                            Task {
                                await appState.endLiveActivity()
                            }
                            
                            logger.logInfo("🔴 Terminated audio session and Live Activity")
                        }
                        
                        // Set up handler for keyboard session expiration (timeout)
                        AppGroupCoordinator.shared.onKeyboardSessionExpired = {
                            logger.logInfo("⏰ Keyboard session expired - cleaning up Live Activity")

                            // End Live Activity when session times out
                            Task {
                                await appState.endLiveActivity()
                            }
                        }

                        // Set up handler for recording state changes
                        AppGroupCoordinator.shared.onRecordingStateChanged = { isRecording in
                            Task {
                                if isRecording {
                                    await appState.updateLiveActivityState(.recording)
                                } else {
                                    await appState.updateLiveActivityState(.idle)
                                }
                            }
                        }

                        // Set up handler for transcription processing
                        AppGroupCoordinator.shared.onTranscriptionTranscribing = {
                            Task {
                                await appState.updateLiveActivityState(.transcribing)
                            }
                        }

                        // Set up handler for AI processing
                        AppGroupCoordinator.shared.onTranscriptionEnhancing = {
                            Task {
                                await appState.updateLiveActivityState(.enhancing)
                            }
                        }

                        // Set up handler for transcription completion - return to idle
                        AppGroupCoordinator.shared.onTranscriptionCompleted = { _ in
                            Task {
                                await appState.updateLiveActivityState(.idle)
                            }
                        }

                        // Set up handler for transcription error - return to idle
                        AppGroupCoordinator.shared.onTranscriptionError = {
                            Task {
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
                            appState.showKeyboardReturnPrompt = false
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
                            // Free on-device LLMs when backgrounding normally - but
                            // NOT during a keyboard session, where the keyboard
                            // relies on the model staying loaded to serve requests
                            // from the background (CoreML/ANE).
                            if !AppGroupCoordinator.shared.isKeyboardSessionActive {
                                Task { await OnDeviceModelMemory.shared.unloadAll(reason: "app backgrounded") }
                            }
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
                    // Discard any App Intent action that arrived during onboarding -
                    // the user never saw the main UI, so firing it once MainView
                    // appears would be surprising. See PendingAppIntentAction.
#if !os(macOS)
                    PendingAppIntentAction.shared.clear()
#endif
                    // Stamp latest release ID so What's New doesn't show for fresh installs
                    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    if let release = WhatsNewCatalog.release(for: currentVersion) {
                        UserDefaultsStorage.appPrivate.set(release.id, forKey: UserDefaultsStorage.Keys.lastSeenWhatsNewVersion)
                    }
                    DefaultAnalyticsService.live.track(.onboardingCompleted)
                }
            }
        }
        .modelContainer(modelContainer)
    }
    
    
    private func attemptReturnToHost(hostId: String) {
        // Keyboard session flow:
        // 1. If we CAN return to host app: Start recording → Return to host
        //    User sees recording already happening when they arrive
        // 2. If we CANNOT return: Start recording → Show return prompt → User manually switches
        //    User sees recording already happening when they arrive
        
        // `.notice` rather than `.info` throughout this path: info-level
        // entries are memory backed, so they are gone by the time a device log
        // is collected - and the app is usually terminated moments after a
        // handoff, which is exactly when a wrong host needs explaining.
        logger.logNotice("🔄 Attempting to return to host: \(hostId)")

        if let url = returnURL(forHostId: hostId) {
            logger.logNotice("🚀 Found return URL, attempting to open: \(url.absoluteString)")

            Task {
                // Check if we have a transcription model selected
                guard let vm = appState.recordViewModel else {
                    logger.logError("❌ RecordViewModel not available")
                    appState.showKeyboardReturnPrompt = true
                    return
                }

                if vm.transcriptionManager.getCurrentTranscriptionModel() == nil {
                    logger.logWarning("⚠️ No transcription model selected - showing keyboard return prompt")
                    appState.showKeyboardReturnPrompt = true
                    return
                }

                // Recording starts before the open is known to have succeeded.
                // `open` only reports failure once it has already tried, and the
                // user arrives in the host app expecting to be recording
                // already, so waiting for the answer would cost the head of the
                // recording. A failure falls back to the prompt below.
                logger.logInfo("🎙️ Starting recording before returning to host app")
                vm.startCaptureAudio(sourceTag: SourceTag.keyboard)

                // Small delay to ensure recording is fully started
                try? await Task.sleep(for: .milliseconds(200))

                // Now return to the host app
                if await UIApplication.shared.open(url) {
                    logger.logNotice("✅ Successfully opened host app: \(hostId) with recording started")
                } else {
                    logger.logError("❌ Failed to open host app: \(hostId)")
                    appState.showKeyboardReturnPrompt = true
                }
            }
        } else {
            logger.logNotice("❌ No URL scheme available for host: \(hostId)")
            // No URL scheme found - start recording and show keyboard return prompt
            // so user can switch back manually and find recording already in progress
            Task {
                if let vm = appState.recordViewModel,
                   vm.transcriptionManager.getCurrentTranscriptionModel() != nil {
                    logger.logInfo("🎙️ Starting recording before showing manual switch sheet")
                    vm.startCaptureAudio(sourceTag: SourceTag.keyboard)
                }
                appState.showKeyboardReturnPrompt = true
            }

            trackUnrecognizedHostIfNeeded(hostId)
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
            Task {
                do {
                    // Start and await prewarm session to ensure it's fully ready
                    try await AudioPrewarmManager.shared.startPrewarmSession()
                    logger.logInfo("🎙️ Prewarm session fully ready")
                    
                    // Extract hostId from URL query parameters
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let hostId = components?.queryItems?.first(where: { $0.name == "hostId" })?.value

                    // Log keyboard session start to Firebase Analytics
                    DefaultAnalyticsService.live.track(.keyboardSessionStarted(hostBundleId: hostId))

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
                        // The keyboard couldn't resolve its host app, so there is
                        // nowhere to teleport back to. Start recording and show the
                        // return prompt so the user can switch back by hand.
                        if let vm = appState.recordViewModel,
                           vm.transcriptionManager.getCurrentTranscriptionModel() != nil {
                            logger.logNotice("🎙️ Starting recording before showing manual switch prompt (no hostId)")
                            vm.startCaptureAudio(sourceTag: SourceTag.keyboard)
                        }
                        appState.showKeyboardReturnPrompt = true
                    }
                    
                    
                    
                    
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session: \(error.localizedDescription)")
                    // If prewarm fails, still try to show keyboard return prompt as fallback
                    appState.showKeyboardReturnPrompt = true
                }
            }
        } else if url.absoluteString.starts(with: "vivadicta://activate-for-keyboard") {
            logger.logInfo("📱 Recognized as keyboard session activation request (text processing)")

            Task {
                do {
                    // The prewarm session is REQUIRED here even though this path
                    // never records. The app declares the `audio` background
                    // mode, and an active AVAudioSession with a running engine
                    // is what keeps the main app resident once the keyboard
                    // returns the user to the host app - which is how the
                    // keyboard's text-processing request gets serviced at all.
                    // Dropping this call suspends the app and text actions
                    // silently stop working. It is a background-execution
                    // anchor, not an audio feature.
                    //
                    // needsMicrophone: false - this path processes text and
                    // never reads the mic, so it holds the session without
                    // acquiring a Bluetooth input route. Requesting one would
                    // drop the user's headphones into headset audio for the
                    // whole timeout in exchange for nothing. A recording
                    // arriving later rebuilds the session with the real route.
                    try await AudioPrewarmManager.shared.startPrewarmSession(needsMicrophone: false)
                    logger.logInfo("🎙️ Prewarm session ready for text processing")

                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    let hostId = components?.queryItems?.first(where: { $0.name == "hostId" })?.value

                    // Same event as the dictation handoff: a keyboard session is
                    // a keyboard session whichever button opened it, and this is
                    // where the unresolved-host rate for text actions shows up
                    // (`host_bundle_id` is "unknown" when the resolver timed out).
                    DefaultAnalyticsService.live.track(.keyboardSessionStarted(hostBundleId: hostId))

                    let timeoutSeconds = AudioPrewarmManager.shared.audioSessionTimeout
                    AppGroupCoordinator.shared.activateKeyboardSession(
                        timeoutSeconds: timeoutSeconds
                    )

                    logger.logInfo("🎙️ Keyboard session activated for text processing")

                    // Return to host app without starting recording
                    if let hostId = hostId {
                        returnToHost(hostId: hostId)
                    } else {
                        appState.showKeyboardReturnPrompt = true
                    }
                } catch {
                    logger.logError("⚠️ Failed to start prewarm session for text processing: \(error.localizedDescription)")
                    appState.showKeyboardReturnPrompt = true
                }
            }
        } else if url.absoluteString == "startRecordFromWidget" {
            logger.logInfo("📱 Recognized as widget recording request")

            // Start recording
            appState.shouldStartRecording = true
            logger.logInfo("🎙️ Starting recording from widget deeplink")
        } else if url.absoluteString == "openAskFromWidget" {
            logger.logInfo("📱 Recognized as widget Ask AI request")

            appState.shouldShowChats = true
        } else if url.absoluteString == "openSearchFromWidget" {
            logger.logInfo("📱 Recognized as widget Search request")

            appState.shouldFocusSearch = true
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
        logger.logNotice("🔄 Returning to host app (no recording): \(hostId)")

        guard let url = returnURL(forHostId: hostId) else {
            logger.logNotice("❌ No return URL for host: \(hostId)")
            trackUnrecognizedHostIfNeeded(hostId)
            appState.showKeyboardReturnPrompt = true
            return
        }

        Task {
            if await UIApplication.shared.open(url) {
                logger.logNotice("✅ Returned to host app: \(hostId)")
            } else {
                logger.logError("❌ Failed to open host app: \(hostId)")
                appState.showKeyboardReturnPrompt = true
            }
        }
    }

    /// Host apps that are known to have no way back, so their bundle IDs are
    /// not worth reporting as unrecognized.
    ///
    /// Two kinds of entry: system services that are not really "apps" the user
    /// came from, and shipping apps already checked by hand and found to
    /// register neither a URL scheme nor a usable universal link.
    private static let knownNoSchemeHosts: Set<String> = [
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
        "ru.ozon.sellerApp",            // Ozon Seller - no known URL scheme
        "kz.origon.empapp",             // KZ telemedicine app - no known URL scheme
        "com.cloud-compiler",           // CodeSnack IDE - no known URL scheme
        "com.corp.messenger.syncer",    // Syncer corporate messenger - no known URL scheme
        "com.yottaram.eMoods",          // eMoods tracker - no known URL scheme
        "com.anton",                    // Not a shipping App Store app - a dev build

        // Apple view services and system apps that register no URL types.
        // Read from the shipping binaries in the simulator runtimes.
        "com.apple.campo",              // Campo (Siri chatbot, iOS 27) - no CFBundleURLTypes
        "com.apple.mobilesms.compose",  // MessagesViewService - the compose sheet over other apps
        "com.apple.ShortcutsUI",        // ShortcutsUI view service - no CFBundleURLTypes

        // Checked by hand: no custom scheme, and no universal link that opens
        // the app at its root.
        "com.deepseek.chat",            // DeepSeek - AASA lists the bundle with an empty paths array
        "com.hevyapp.hevy",             // Hevy - AASA has no root path, only per-object routes
        "com.stably.orca.mobile",       // Orca IDE - no AASA, no known scheme
        "org.edupage",                  // EduPage - no AASA, no known scheme
        "com.rivetrune.cognilog",       // CogniLog - no AASA, no known scheme
        "com.t3tools.t3code",           // T3 Code - t3.codes serves no AASA
        "com.davetech.todo",            // MinimaList to-do - no AASA, no known scheme
        "cc.calacatta.happiest"         // Not on any App Store storefront; calacatta.cc does not resolve
    ]

    /// Reports a host app we could not return to, so its URL scheme can be
    /// looked up and added to `returnURL(forHostId:)` later.
    ///
    /// Called from both keyboard handoffs - dictation and text processing.
    /// Apps used only for text actions would otherwise never be reported, and
    /// their users would keep losing the teleport back with nothing to show for
    /// it in the analytics.
    private func trackUnrecognizedHostIfNeeded(_ hostId: String) {
        guard !Self.knownNoSchemeHosts.contains(hostId) else { return }
        DefaultAnalyticsService.live.track(.unrecognizedHostApp(bundleId: hostId))
    }

    /// The URL that sends the user back to `bundleId`, or nil when there is no
    /// known way back.
    ///
    /// Most entries are custom schemes. A few apps register none but do claim a
    /// universal link in their `apple-app-site-association`, which works here
    /// because the host app is installed by definition - it is the app the
    /// keyboard was just typing into. The trade-off is that a user who has told
    /// iOS to open that domain in Safari lands on the web page instead of
    /// getting the manual return prompt.
    ///
    /// Not comprehensive: plenty of apps publish no way back at all. Those are
    /// listed in `knownNoSchemeHosts` so they stop being reported as
    /// unrecognized.
    private func returnURL(forHostId bundleId: String) -> URL? {
        let knownURLs: [String: String] = [
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
            "ru.yandex.mobile.translate": "yandextranslate://",

            // Verified against the app's own Info.plist, official docs, or the
            // shipping binary.
            "app.swiftgram.ios": "sg://",            // NOT tg:// - shared with official Telegram
            "com.openminis.app": "minis://",
            "com.tencent.xin": "weixin://",
            "com.spotify.client.L32G8C83V9": "spotify://",  // team-ID-suffixed Spotify build
            "com.apple.reminders": "x-apple-reminderkit://", // NOT x-apple-reminder://, unregistered
            "com.letterboxd.LetterboxdApp": "letterboxd://",
            "eusoft.eudic.ip": "eudic://",
            "com.ex3ndr.happy": "happy://",          // Expo scheme in the app's own app.config.js
            "psyche.kelivo": "kelivo://",
            "com.codality.NotationalFlow": "simplenote://",  // this bundle id is Simplenote
            "com.agiletortoise.Drafts5": "drafts://",
            "com.ubercab.UberClient": "uber://",
            "com.tinyspeck.chatlyio": "slack://open", // this bundle id is Slack

            // Corroborated across independent sources but not read from the
            // shipping app, so a miss is possible - it degrades to the prompt.
            "notion.id": "notion://",
            "com.meituan.imeituan": "imeituan://",
            "com.newin.nplayer.basic": "nplayer-http://",
            "com.evernote.iPhone.Evernote": "evernote://",
            "jp.naver.line": "line://",
            "com.google.ios.youtube": "youtube://",
            "com.ebay.iphone": "ebay://",
            "com.google.Docs": "googledocs://",
            "com.taobao.taobao4iphone": "taobao://",
            "company.thebrowser.ArcMobile2": "arcmobile2://",

            // Single-source or inferred from a sibling platform. Weaker still,
            // and kept only because a miss costs nothing beyond the prompt the
            // user would otherwise have gotten anyway.
            "com.alibaba.sourcing": "enalibaba://",  // one scheme database, no vendor doc
            "com.automattic.beeper": "beeper://",    // documented for Beeper Desktop, assumed shared
            "com.xiaojukeji.didi": "diditaxi://",    // long-cited legacy scheme, no primary source
            // VK Messenger. NOT https://vk.me/ - the main VK client claims that
            // domain with the same wildcard, so iOS picks between them.
            "com.vk.vkme": "vkme://",

            // No custom scheme; universal link confirmed in the app's AASA file.
            "com.google.ios.ytcreator": "https://studio.youtube.com/",
            "com.amazon.AmazonDE": "https://www.amazon.de/",
            "ru.ivi": "https://www.ivi.ru/",
            "ru.oneme.app": "https://max.ru/",
            "ru.ozon.OzonStore": "https://www.ozon.ru/",
            "com.amazon.AmazonUK": "https://www.amazon.co.uk/",
            "com.amazon.Amazon": "https://www.amazon.com/",
            "com.ClassDojo": "https://www.classdojo.com/ul/home",
            "com.kouzoh.ios.mercari": "https://jp.mercari.com/",
            "com.ubercab.UberEats": "https://www.ubereats.com/"
        ]

        return knownURLs[bundleId].flatMap(URL.init(string:))
    }
    
    func updateShortcutItems() {
        let needHelpAction = UIApplicationShortcutItem(
            type: QuickActionType.needHelp.rawValue,
            localizedTitle: "Need help?",
            localizedSubtitle: "Open the documentation",
            icon: UIApplicationShortcutIcon(systemImageName: "questionmark.circle"),
            userInfo: [:])
        let searchAction = UIApplicationShortcutItem(
            type: QuickActionType.search.rawValue,
            localizedTitle: "Search",
            localizedSubtitle: "Find notes instantly",
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
            userInfo: [:])
        let askAIAction = UIApplicationShortcutItem(
            type: QuickActionType.askAI.rawValue,
            localizedTitle: "Ask AI",
            localizedSubtitle: "Chat with your notes",
            icon: UIApplicationShortcutIcon(systemImageName: "bubble.left.and.bubble.right.fill"),
            userInfo: [:])
        let recordAction = UIApplicationShortcutItem(
            type: QuickActionType.startRecord.rawValue,
            localizedTitle: "Record",
            localizedSubtitle: "Turn your voice into text",
            icon: UIApplicationShortcutIcon(systemImageName: "microphone.circle.fill"),
            userInfo: [:])

        UIApplication.shared.shortcutItems = [needHelpAction, searchAction, askAIAction, recordAction]
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
    case needHelp
}
