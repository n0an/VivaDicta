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

    private func handleTranscription(_ text: String) {
        guard !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
        UIPasteboard.general.string = text
    }
    
    
    // MARK: - Properties
    let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dictationState.onTranscriptionReady = { [weak self] text in
            self?.handleTranscription(text)
        }

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
    
    deinit {
        dictationState.stop()
    }

}

struct VivaDictaKeyboardToolbarView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
//            Button {
//                startRecording()
//            } label: {
//                Image(systemName: "microphone.circle")
//                    .font(.system(size: 24))
//            }
//            .buttonStyle(.glassProminent)
//            .tint(.orange)
            
            
            if dictationState.uiState == .notReady {
                
                if #available(iOS 26.0, *) {
                    Button(action: handleMic) {
                        Label("Activate", systemImage: "mic.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .glassEffect(.regular.tint(.gray.opacity(0.7)).interactive())
                } else {
                    Button(action: handleMic) {
                        Label("Activate", systemImage: "mic.slash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                }
                
                
                
            } else {
                Button(action: handleMic) {
                    
                    
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(dictationState.micColor)
                        .frame(width: 44, height: 44)
                        .debugBorder()
                    
                    
                    
                    
                    //                    Image(systemName: dictationState.uiState == .notReady ? "mic.slash" : "mic.fill")
                    //                        .font(.system(size: 18, weight: .bold))
                    //                        .foregroundColor(dictationState.micColor)
                    ////                        .frame(width: 32, height: 32)
                    //                        .debugBorder()
                    //                        .background(toolbarBackgroundColor)
                    //                        .clipShape(.circle)
                    //                        .debugBorder()
                    
                    
                    
                    
                }
            }
            
            

            
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func handleMic() {
        guard dictationState.uiState != .notReady else {
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
