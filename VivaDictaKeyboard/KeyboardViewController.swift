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

    // Services (internal so extensions can access them)
    // Using protocol types for easier testing and mocking
    lazy var appStateMonitoringService: AppStateMonitoring = AppStateMonitoringService()
    lazy var recordingCoordinator: RecordingCoordination = RecordingCoordinator()
    private lazy var urlOpeningService: URLOpening = URLOpeningService(
        extensionContext: self.extensionContext,
        responderChainRoot: self
    )

    // State
    var appStateViewModel = AppStateViewModel()
    var keyboardStateManager = KeyboardStateManager()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup service delegates
        setupServiceDelegates()

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

    private func setupServiceDelegates() {
        appStateMonitoringService.delegate = self
        recordingCoordinator.delegate = self
    }

    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()

        // Check initial app state using the monitoring service
        appStateMonitoringService.updateStates()

        // Setup the keyboard view with custom toolbar
        setupKeyboardView { [weak self] controller in
            KeyboardCustomView(
                controller: controller,
                stateManager: self?.keyboardStateManager,
                appStateViewModel: self?.appStateViewModel,
                onCancelRecording: { self?.handleCancelRecording() },
                onStopRecording: { self?.handleStopRecording() },
                onCancelProcessing: { self?.handleCancelProcessing() },
                onRecordTapped: { self?.handleRecordButtonTap() }
            )
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Start monitoring app state using the service
        appStateMonitoringService.startMonitoring()

        // Setup Darwin notification observers for immediate updates
        setupDarwinNotificationObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Stop monitoring app state using the service
        appStateMonitoringService.stopMonitoring()

        // Cancel any pending recording timeout using the coordinator
        recordingCoordinator.cancelRecordingTimeout()

        // Clean up Darwin notification observers specific to keyboard
        AppGroupCoordinator.shared.removeKeyboardObservers()
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
            // Stop recording using coordinator
            recordingCoordinator.stopRecording()
            return
        }

        // Check current app state
        let isAppActive = appStateMonitoringService.isMainAppActive
        logger.info("🎤 Current app state: \(isAppActive ? "ACTIVE" : "SUSPENDED")")

        if !isAppActive {
            // App is suspended - open it via URL scheme
            logger.info("🎤 App is suspended, opening via URL scheme")
            openMainAppViaURLScheme()
        } else {
            // App is active - start recording via coordinator
            logger.info("🎤 App is active, starting recording via coordinator")

            // Clear any previous cancel flag
            keyboardStateManager.didCancelRecording = false

            // Refresh flow modes to get latest from main app
            keyboardStateManager.refreshFlowModes()

            // Transition to recording state
            keyboardStateManager.startRecording()

            // Force keyboard view to update
            viewWillSetupKeyboardView()

            // Start recording via coordinator (which also starts timeout)
            recordingCoordinator.startRecording()
        }
    }

    private func handleCancelRecording() {
        logger.info("🎤 Cancel recording tapped")

        // Mark that we canceled to prevent text insertion
        keyboardStateManager.didCancelRecording = true

        // Cancel recording via coordinator
        recordingCoordinator.cancelRecording()

        // Return to idle state
        keyboardStateManager.cancelRecording()

        // Force keyboard view to update
        viewWillSetupKeyboardView()
    }

    private func handleStopRecording() {
        logger.info("🎤 Stop recording tapped")

        // Clear cancel flag - this is a normal stop with transcription
        keyboardStateManager.didCancelRecording = false

        // Stop recording via coordinator
        recordingCoordinator.stopRecording()

        // Note: The transition to processing state will happen
        // when we receive the recordingStopped notification
    }

    private func handleCancelProcessing() {
        logger.info("❌ Cancel processing tapped")

        // Mark that we canceled to prevent text insertion
        keyboardStateManager.didCancelRecording = true

        // Cancel recording via coordinator
        recordingCoordinator.cancelRecording()

        // Return to idle state
        keyboardStateManager.cancelRecording()

        // Force keyboard view to update
        viewWillSetupKeyboardView()
    }

    private func openMainAppViaURLScheme() {
        // Open main app with recording intent
        let url = URL(string: "vivadicta://record-for-keyboard")!
        urlOpeningService.openURL(url, completion: nil)
    }
}

// MARK: - AppStateMonitoringDelegate

extension KeyboardViewController: AppStateMonitoringDelegate {

    func appStateDidChange(isActive: Bool) {
        appStateViewModel.isMainAppActive = isActive
    }

    func recordingStateDidChange(isRecording: Bool) {
        appStateViewModel.isRecording = isRecording

        // Update keyboard view state when recording status changes
        if isRecording {
            // Recording started - show recording view
            keyboardStateManager.startRecording()
        } else if keyboardStateManager.viewState == .recording {
            // Recording stopped - return to idle
            keyboardStateManager.finishProcessing()
        }

        // Force keyboard view to update
        viewWillSetupKeyboardView()
    }
}

// MARK: - RecordingCoordinatorDelegate

extension KeyboardViewController: RecordingCoordinatorDelegate {

    func recordingCoordinatorDidStartRecording() {
        // Coordinator has sent the start recording request
        // No additional action needed here as Darwin notifications will handle state updates
    }

    func recordingCoordinatorDidStopRecording() {
        // Coordinator has sent the stop recording request
        // No additional action needed here as Darwin notifications will handle state updates
    }

    func recordingCoordinatorDidCancelRecording() {
        // Coordinator has sent the cancel recording request
        // No additional action needed here as Darwin notifications will handle state updates
    }

    func recordingCoordinatorDidTimeout() {
        logger.info("❌ Recording coordinator timeout - handling error")

        // Check if we're still waiting for recording to start
        if keyboardStateManager.viewState == .recording && !appStateViewModel.isRecording {
            // Transition to error state
            keyboardStateManager.processingStage = .error("Recording failed to start")
            keyboardStateManager.viewState = .processing
            viewWillSetupKeyboardView()

            // Return to idle after showing error
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                self.keyboardStateManager.cancelRecording()
                self.viewWillSetupKeyboardView()
            }
        }
    }
}
