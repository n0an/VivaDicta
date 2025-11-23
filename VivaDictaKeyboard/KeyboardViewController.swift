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

struct ActivateButton: View {
    @Environment(\.openURL) private var openURL
    @State var isAnimating = false
    
    var borderWidth: CGFloat
    weak var controller: KeyboardViewController?
    
    var body: some View {
        Button {
            // Build URL with hostId as query parameter
            var urlString = "vivadicta://record-for-keyboard"
            if let hostId = controller?.hostApplicationBundleId {
                // URL encode the hostId to handle special characters
                if let encodedHostId = hostId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    urlString += "?hostId=\(encodedHostId)"
                }
            }

            if let url = URL(string: urlString) {
                controller?.logger.logInfo("📱 Opening main app with URL: \(url.absoluteString)")
                openURL(url)
            }
        } label: {
            
            Label("Activate", systemImage: "mic.slash")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.primary)
                .colorInvert()
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.gray.gradient, in: .capsule(style: .continuous))
            
                .background {
                    Capsule(style: .continuous)
                    
                        .fill(AngularGradient(colors: [.teal, .pink, .teal], center: .center, angle: .degrees(isAnimating ? 360 : 0)))
                        .blur(radius: 10)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 7).repeatForever(autoreverses: false)) {
                                isAnimating = true
                            }
                        }
                        .onDisappear {
                            isAnimating = false
                        }
                }
            
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.black.opacity(0.5), lineWidth: borderWidth)
                }
        }
    }
}

struct MicButton: View {
    @State var isAnimating = false
    
    var fontSize: CGFloat
    var padding: CGFloat
    var backgroundColor: Color
    var borderWidth: CGFloat
    
    var onTapAction: () -> Void
    
    
    var body: some View {
        
        
        Button {
            onTapAction()
        } label: {
            
            Image(systemName: "microphone.circle")
                .foregroundColor(.primary)
                .font(.system(size: fontSize))
                .padding(padding)
                .background(backgroundColor.gradient, in: .circle)
                
                .background {
                    Circle()
                    
                        .fill(AngularGradient(colors: [.teal, .pink, .teal], center: .center, angle: .degrees(isAnimating ? 360 : 0)))
                        .blur(radius: 10)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 7).repeatForever(autoreverses: false)) {
                                isAnimating = true
                            }
                        }
                        .onDisappear {
                            isAnimating = false
                        }
                }
            
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.5), lineWidth: borderWidth)
                }
        }
        
        
        
    }
}


struct VivaDictaKeyboardToolbarView: View {
    @Environment(KeyboardDictationState.self) var dictationState
    @Environment(\.openURL) private var openURL

    weak var controller: KeyboardViewController?

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            if dictationState.uiState == .notReady {
                if #available(iOS 26.0, *) {
                    ActivateButton(borderWidth: 0, controller: controller)
                        .glassEffect(.regular.tint(.gray.opacity(1.0)).interactive())
                    
                } else {
                    ActivateButton(borderWidth: 0.5, controller: controller)
                }
                
            } else {
                
                if #available(iOS 26.0, *) {
                    MicButton(
                        fontSize: 34,
                        padding: 6,
                        backgroundColor: .orange.opacity(0.5),
                        borderWidth: 0,
                        onTapAction: handleMic)
                    
                        .glassEffect(.regular.tint(.orange.opacity(1.0)).interactive())
                    
                } else {
                    
                    MicButton(
                        fontSize: 36,
                        padding: 0,
                        backgroundColor: .orange,
                        borderWidth: 0.5,
                        onTapAction: handleMic)

                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        // Build URL with hostId as query parameter
        var urlString = "vivadicta://record-for-keyboard"
        if let hostId = controller?.hostApplicationBundleId {
            // URL encode the hostId to handle special characters
            // Doc - https://docs.keyboardkit.com/documentation/keyboardkit/host-article#Host-Application-Bundle-Identifier
            if let encodedHostId = hostId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?hostId=\(encodedHostId)"
            }
        }

        if let url = URL(string: urlString) {
            controller?.logger.logInfo("📱 Opening main app with URL: \(url.absoluteString)")
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
