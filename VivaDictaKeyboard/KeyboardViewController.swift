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
            
            VStack(spacing: 0) {
                KeyboardView(
                    state: controller.state,
                    services: controller.services,
                    buttonContent: { $0.view },
                    buttonView: { $0.view },
                    collapsedView: { $0.view },
                    emojiKeyboard: { $0.view },
                    toolbar: { params in
                        RecordingToolbar(
                            onRecordTapped: {
                                self?.handleRecordButtonTap()
                            }
                        )
                    }
                )
            }
            
            
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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
        
        // Open main app with recording intent
        let url = URL(string: "vivadicta://record-for-keyboard")!
        logger.info("🎤 Opening URL: \(url.absoluteString)")

        // Method 1: Try extensionContext.open (primary method)
        self.extensionContext?.open(url) { [weak self] success in
            if success {
                self?.logger.info("🎤 ✅ Successfully opened main app via extensionContext")
            } else {
                self?.logger.info("🎤 ⚠️ extensionContext.open failed, trying alternative methods...")
                Task { @MainActor in
                    self?.tryAlternativeURLOpening(url)
                }
            }
        }
    }

    private func tryAlternativeURLOpening(_ url: URL) {
        logger.info("🎤 Trying alternative URL opening methods...")

        // Method 2: Try UIApplication directly via key-value coding
        if let sharedApp = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
            logger.info("🎤 Found UIApplication using sharedApplication")

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
            logger.info("🎤 Could not get UIApplication via sharedApplication")
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
            Task { @MainActor in
                textDocumentProxy.insertText("[Unable to open VivaDicta. Please open the app manually] ")
            }
        }
    }

}
