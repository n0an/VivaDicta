//
//  KeyboardViewController.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import UIKit
import KeyboardKit
import SwiftUI
import os

class KeyboardViewController: KeyboardInputViewController {

    // MARK: - Properties
    let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")
    private var transcriptionObserver: Timer?
    private let appStateDetector = AppStateDetector()
    private let recordingStateDetector = RecordingStateDetector()
    private var appStateTimer: Timer?
    var appStateViewModel = AppStateViewModel()
    var keyboardStateManager = KeyboardStateManager()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create keyboard app configuration
        let keyboardApp = KeyboardApp(
            name: "VivaDicta Keyboard",
            appGroupId: AppGroupConfig.appGroupId,
            deepLinks: .init(app: "vivadicta://")
        )

        // Setup the keyboard
        setup(for: keyboardApp) { [weak self] result in
            self?.logger.info("Keyboard setup result: \(String(describing: result), privacy: .public)")
        }
    }

    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()

        // Check initial app state
        updateAppState()

        // Setup the keyboard view with custom toolbar
        setupKeyboardView { [weak self] controller in
            guard let self = self else {
                return AnyView(EmptyView())
            }

            // Show custom view based on keyboard state
            if self.keyboardStateManager.viewState == .recording {
                return AnyView(
                    RecordingStateView(
                        stateManager: self.keyboardStateManager,
                        onCancelTapped: {
                            self.handleCancelRecording()
                        },
                        onStopTapped: {
                            self.handleStopRecording()
                        }
                    )
                )
            } else if self.keyboardStateManager.viewState == .processing {
                return AnyView(
                    ProcessingStateView(
                        processingStage: .init(
                            get: { self.keyboardStateManager.processingStage },
                            set: { self.keyboardStateManager.processingStage = $0 }
                        ),
                        onCancel: {
                            self.handleCancelProcessing()
                        }
                    )
                )
            } else {
                // Show normal keyboard with recording toolbar
                return AnyView(
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
                                    isMainAppActive: self.appStateViewModel.isMainAppActive,
                                    isRecording: self.appStateViewModel.isRecording,
                                    onRecordTapped: {
                                        self.handleRecordButtonTap()
                                    }
                                )
                            }
                        )
                    }
                )
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Start monitoring app state periodically
        startAppStateMonitoring()

        // Setup Darwin notification observers for immediate updates
        setupDarwinNotificationObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop monitoring app state
        stopAppStateMonitoring()

        // Clean up Darwin notification observers specific to keyboard
        AppGroupCoordinator.shared.removeKeyboardObservers()
    }

    // MARK: - App State Monitoring

    private func startAppStateMonitoring() {
        // Stop any existing timer
        stopAppStateMonitoring()

        // Check state immediately
        updateAppState()

        // Set up periodic monitoring (every 5 seconds matches heartbeat interval)
        appStateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAppState()
            }
        }

        logger.info("🔍 Started app state monitoring")
    }

    private func stopAppStateMonitoring() {
        appStateTimer?.invalidate()
        appStateTimer = nil
        logger.info("🔍 Stopped app state monitoring")
    }

    private func updateAppState() {
        let previousState = appStateViewModel.isMainAppActive
        let newState = appStateDetector.isMainAppActive()

        // Check recording state using heartbeat detector
        let previousRecordingState = appStateViewModel.isRecording
        let newRecordingState = recordingStateDetector.isRecordingActive()

        Task { @MainActor in
            self.appStateViewModel.isMainAppActive = newState
            self.appStateViewModel.isRecording = newRecordingState

            if previousState != newState {
                self.logger.info("📱 App state changed: \(newState ? "ACTIVE ✅" : "SUSPENDED ⏸️")")
            }

            if previousRecordingState != newRecordingState {
                self.logger.info("🎤 Recording state changed: \(newRecordingState ? "RECORDING 🔴" : "NOT RECORDING ⏹️")")

                // Log heartbeat age for debugging
                if let age = self.recordingStateDetector.recordingHeartbeatAge() {
                    self.logger.info("🎤 💙 Recording heartbeat age: \(String(format: "%.1f", age))s")
                }

                // Update keyboard view state when recording status changes
                if newRecordingState {
                    // Recording started - show recording view
                    self.keyboardStateManager.startRecording()
                } else if self.keyboardStateManager.viewState == .recording {
                    // Recording stopped - return to idle
                    self.keyboardStateManager.finishProcessing()
                }

                // Force keyboard view to update
                self.viewWillSetupKeyboardView()
            }
        }
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

        // Check if currently recording
        if appStateViewModel.isRecording {
            // Stop recording
            logger.info("🛑 Stopping recording via Darwin notification")
            AppGroupCoordinator.shared.requestStopRecording()
            return
        }

        // Check current app state
        let appState = appStateDetector.detectAppState()
        logger.info("🎤 Current app state: \(appState == .active ? "ACTIVE" : "SUSPENDED")")

        if appState == .suspended {
            // App is suspended - open it via URL scheme
            logger.info("🎤 App is suspended, opening via URL scheme")
            openMainAppViaURLScheme()
        } else {
            // App is active - send Darwin notification to start recording
            logger.info("🎤 App is active, sending Darwin notification to start recording")
            AppGroupCoordinator.shared.requestStartRecording()

            // Clear any previous cancel flag
            keyboardStateManager.didCancelRecording = false

            // Refresh flow modes to get latest from main app
            keyboardStateManager.refreshFlowModes()

            // Transition to recording state
            keyboardStateManager.startRecording()

            // Force keyboard view to update
            viewWillSetupKeyboardView()
        }
    }

    private func handleCancelRecording() {
        logger.info("🎤 Cancel recording tapped")

        // If recording is active, cancel it (without transcription)
        if appStateViewModel.isRecording {
            AppGroupCoordinator.shared.requestCancelRecording()
        }

        // Mark that we canceled to prevent text insertion
        keyboardStateManager.didCancelRecording = true

        // Return to idle state
        keyboardStateManager.cancelRecording()

        // Force keyboard view to update
        viewWillSetupKeyboardView()
    }

    private func handleStopRecording() {
        logger.info("🎤 Stop recording tapped")

        // Clear cancel flag - this is a normal stop with transcription
        keyboardStateManager.didCancelRecording = false

        // Send stop recording request
        AppGroupCoordinator.shared.requestStopRecording()

        // Note: The transition to processing state will happen
        // when we receive the recordingStopped notification
    }

    private func handleCancelProcessing() {
        logger.info("❌ Cancel processing tapped")

        // Mark that we canceled to prevent text insertion
        keyboardStateManager.didCancelRecording = true

        // Request cancellation if still recording
        if appStateViewModel.isRecording {
            AppGroupCoordinator.shared.requestCancelRecording()
        }

        // Return to idle state
        keyboardStateManager.cancelRecording()

        // Force keyboard view to update
        viewWillSetupKeyboardView()
    }

    private func openMainAppViaURLScheme() {
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
                        Task { @MainActor in
                            self?.openURLViaResponderChain(url)
                        }
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


// FIXME: - not used, perhaps delete
@MainActor
struct URLOpener {
  let responder: UIResponder

  func open(urlString: String) {
    if let url = URL(string: urlString) {
      var optionalResponder: UIResponder? = responder
      let selector = NSSelectorFromString("openURL:")
      while let responder = optionalResponder {
        if responder.responds(to: selector) {
          responder.perform(selector, with: url)
          return
        }
        optionalResponder = responder.next
      }
      print("Can't open", urlString)
    } else {
      print("Can't open", urlString)
    }
  }
}
