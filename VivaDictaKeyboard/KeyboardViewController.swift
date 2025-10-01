//
//  KeyboardViewController.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import UIKit
import KeyboardKit
import SwiftUI
import OSLog

class KeyboardViewController: KeyboardInputViewController {

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")
    private let appGroupId = "group.com.antonnovoselov.VivaDicta"
    private var transcriptionObserver: Timer?

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Test App Group access
        if let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            sharedDefaults.set("test_from_keyboard", forKey: "app_group_test")
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: "keyboard_test_timestamp")
            sharedDefaults.synchronize()
            logger.info("✅ App Group test write successful")
            logger.info("✅ Written test value: test_from_keyboard")
            logger.info("✅ Can read back: \(sharedDefaults.string(forKey: "app_group_test") ?? "nil", privacy: .public)")
        } else {
            logger.error("❌ ERROR: Cannot access App Group: \(self.appGroupId)")
        }

        // Create keyboard app configuration
        let keyboardApp = KeyboardApp(
            name: "VivaDicta Keyboard",
            appGroupId: appGroupId,
            deepLinks: .init(app: "vivadicta://")
        )

        // Setup the keyboard
        setup(for: keyboardApp) { [weak self] result in
            self?.logger.info("Keyboard setup result: \(String(describing: result), privacy: .public)")
        }
    }

    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()

        // Setup the keyboard view with custom toolbar
        setupKeyboardView { [weak self] controller in
            VivaDictaKeyboardView(
                controller: controller,
                appGroupId: self?.appGroupId ?? "",
                onRecordTapped: { [weak self] in
                    self?.handleRecordButtonTap()
                }
            )
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startMonitoringTranscriptions()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMonitoringTranscriptions()
    }

    // MARK: - Recording

    private func handleRecordButtonTap() {
        logger.info("🎤 Record button tapped")

        // Check if keyboard has full access
        let hasFullAccess = self.hasFullAccess
        logger.info("🎤 Has Full Access: \(hasFullAccess)")

        if !hasFullAccess {
            logger.error("🎤 ❌ ERROR: Keyboard doesn't have Full Access permission")
            logger.error("🎤 ❌ User needs to enable 'Allow Full Access' in Settings → Keyboards")

            // Show error to user (insert message in text field)
            textDocumentProxy.insertText("[Please enable 'Allow Full Access' for VivaDicta Keyboard in Settings] ")
            return
        }

        // Quick App Group verification
        if let sharedDefaults = UserDefaults(suiteName: appGroupId) {
            logger.info("🔍 App Group check - Can read main app test: \(sharedDefaults.string(forKey: "main_app_test") ?? "not found")")
        } else {
            logger.error("🎤 ❌ ERROR: Cannot access App Group")
        }

        // Open main app with recording intent
        let url = URL(string: "vivadicta://record-for-keyboard")!
        logger.info("🎤 Opening URL: \(url.absoluteString)")

        // Method 1: Try extensionContext.open (primary method)
        self.extensionContext?.open(url) { [weak self] success in
            if success {
                self?.logger.info("🎤 ✅ Successfully opened main app via extensionContext")
            } else {
                self?.logger.info("🎤 ⚠️ extensionContext.open failed, trying alternative methods...")
                DispatchQueue.main.async {
                    self?.tryAlternativeURLOpening(url)
                }
            }
        }
    }

    private func tryAlternativeURLOpening(_ url: URL) {
        logger.info("🎤 Trying alternative URL opening methods...")

        // Method 2: Try UIApplication directly via key-value coding
        if let sharedApp = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
            logger.info("🎤 Found UIApplication via KVC")

            if sharedApp.canOpenURL(url) {
                logger.info("🎤 canOpenURL returned true")
                sharedApp.open(url, options: [:]) { [weak self] success in
                    if success {
                        self?.logger.info("🎤 ✅ Successfully opened main app via UIApplication.open")
                    } else {
                        self?.logger.error("🎤 ❌ UIApplication.open failed")
                        self?.openURLViaResponderChain(url)
                    }
                }
                return
            } else {
                logger.warning("🎤 ⚠️ canOpenURL returned false")
            }
        } else {
            logger.info("🎤 Could not get UIApplication via KVC")
        }

        // Fallback to responder chain method
        openURLViaResponderChain(url)
    }

    private func openURLViaResponderChain(_ url: URL) {
        logger.info("🎤 Trying responder chain method...")

        // Method 3: Walk responder chain to find openURL: selector
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")

        // Find a responder that can handle openURL:
        while let r = responder, !r.responds(to: selector) {
            responder = r.next
        }

        if let responder = responder {
            logger.info("🎤 Found responder that responds to openURL:")
            _ = responder.perform(selector, with: url)
            logger.info("🎤 ✅ Attempted to open main app via responder chain")
        } else {
            logger.error("🎤 ❌ All URL opening methods failed")

            // Show error message to user
            DispatchQueue.main.async { [weak self] in
                self?.textDocumentProxy.insertText("[Unable to open VivaDicta. Please open the app manually] ")
            }
        }
    }

    // MARK: - Transcription Monitoring

    private func startMonitoringTranscriptions() {
        logger.info("👁️ Starting transcription monitoring")
        // Check for new transcriptions every 0.5 seconds
        transcriptionObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForNewTranscription()
        }
    }

    private func stopMonitoringTranscriptions() {
        logger.info("👁️ Stopping transcription monitoring")
        transcriptionObserver?.invalidate()
        transcriptionObserver = nil
    }

    private func checkForNewTranscription() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupId) else {
            logger.error("👁️ ERROR: Could not access App Group UserDefaults")
            return
        }

        if let transcribedText = sharedDefaults.string(forKey: "lastTranscribedText"),
           !transcribedText.isEmpty {
            logger.info("👁️ Found transcribed text: \(String(transcribedText.prefix(50)), privacy: .public)...")

            // Insert the transcribed text
            textDocumentProxy.insertText(transcribedText)
            logger.info("👁️ Inserted text to document proxy")

            // Clear the shared text
            sharedDefaults.removeObject(forKey: "lastTranscribedText")
            sharedDefaults.synchronize()
            logger.info("👁️ Cleared transcribed text from App Group")
        }
    }
}

// MARK: - Custom Keyboard View

struct VivaDictaKeyboardView: View {
    let controller: KeyboardController
    let appGroupId: String
    let onRecordTapped: () -> Void

    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 0) {
            // Custom recording toolbar
            RecordingToolbar(
                isRecording: $isRecording,
                onRecordTapped: {
                    onRecordTapped()
                    isRecording = true
                     
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        isRecording = false
                    }
                }
            )
//            .frame(height: 44)
            .background(Color(UIColor.systemGray6))
            
            // Standard keyboard view
            KeyboardView(
                state: controller.state,
                services: controller.services
            )
        }
    }
}
