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
    
    let dictationState = KeyboardDictationState()
    
    @objc func handleTranscription(notification: Notification) {
        guard let text = notification.userInfo?["text"] as? String, !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
        UIPasteboard.general.string = text
    }
    
    
    // MARK: - Properties
    let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")
    
    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTranscription(notification:)),
            name: .didFinalizeTranscription,
            object: nil
        )
        
        dictationState.start()
        
        // Create keyboard app configuration
        let keyboardApp = KeyboardApp(
            name: "VivaDicta Keyboard",
            appGroupId: AppGroupCoordinator.shared.appGroupId,
            deepLinks: .init(app: "vivadicta://")
        )

        // Setup the keyboard
        setup(for: keyboardApp) { [weak self] result in
            self?.logger.logInfo("Keyboard setup result: \(String(describing: result))")
        }
    }
    
    override func viewWillSetupKeyboardView() {
        super.viewWillSetupKeyboardView()

        // Setup the keyboard view with our custom view that switches based on state
        setupKeyboardView { [weak self] controller in
            KeyboardCustomView(controller: controller)
                .environment(self?.dictationState ?? KeyboardDictationState())
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Remove any height constraints to allow natural sizing
        view.constraints.filter { constraint in
            constraint.firstAttribute == .height || constraint.secondAttribute == .height
        }.forEach { constraint in
            constraint.isActive = false
        }
    }
}

struct VivaDictaKeyboardToolbarView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            Button(action: handleMic) {
                Image(systemName: dictationState.uiState == .notReady ? "mic.slash" : "mic.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(dictationState.micColor)
                    .frame(width: 32, height: 32)
                    .background(toolbarBackgroundColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    private func handleMic() {
        if dictationState.uiState == .notReady {
            openMainAppForHotMic()
            return
        }

        if dictationState.uiState == .error {
            clearErrorState()
        }

        if dictationState.uiState == .ready {
            // Start recording when mic is tapped and ready
            dictationState.requestStartRecording()
        } else if dictationState.uiState == .recording {
            // If already recording, stop it
            dictationState.requestStopRecording()
        }
    }

    private func openMainAppForHotMic() {
        if let url = URL(string: "vivadicta://record-for-keyboard") {
            openURL(url)
        }
    }

    private func clearErrorState() {
        dictationState.errorMessage = nil
        dictationState.transcriptionStatus = .idle
        AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
    }
    
    var toolbarBackgroundColor: Color {
        switch dictationState.uiState {
        case .notReady:
            return Color(.systemGray5)
        case .ready:
            return Color.green.opacity(0.15)
        case .recording:
            return Color.red.opacity(0.15)
        case .processing:
            return Color.primary.opacity(0.1)
        case .error:
            return Color.orange.opacity(0.15)
        }
    }
}
