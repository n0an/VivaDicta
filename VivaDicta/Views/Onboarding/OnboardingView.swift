//
//  OnboardingView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0
    @State private var permissionState: MicrophonePermissionState = .undetermined
//    @State private var showingFullAccessInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button {
                    withAnimation {
                        currentPage -= 1
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .opacity(currentPage > 0 ? 1 : 0)
                .disabled(currentPage == 0)

                Spacer()
                
                if currentPage == 2 {
                    Button("Skip") {
                        onComplete()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.easeInOut, value: currentPage)

            // Swipeable content
            TabView(selection: $currentPage) {
                OnboardingWelcomePage()
                    .tag(0)

                OnboardingMicrophonePage(permissionState: $permissionState)
                    .tag(1)

                OnboardingKeyboardPage()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom buttons - morph based on current page
            VStack(spacing: 12) {
                switch currentPage {
                case 0:
                    // Welcome page - Get Started
                    OnboardingPrimaryButton(title: "Get Started") {
                        withAnimation {
                            currentPage = 1
                        }
                    }

                case 1:
                    // Microphone page
                    switch permissionState {
                    case .granted:
                        OnboardingPrimaryButton(
                            title: "Continue",
                            icon: "checkmark.circle.fill",
                            color: .green
                        ) {
                            withAnimation {
                                currentPage = 2
                            }
                        }
                    case .denied:
                        OnboardingPrimaryButton(
                            title: "Open Settings",
                            icon: "gear",
                            color: .orange,
                            action: openSettings
                        )

                        Text("Microphone access was denied. Please enable it in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    case .undetermined:
                        OnboardingPrimaryButton(
                            title: "Enable Microphone Access",
                            icon: "mic.fill",
                            color: .green,
                            action: requestMicrophonePermission
                        )
                    }

                case 2:
                    // Keyboard page
                    OnboardingPrimaryButton(
                        title: "Open Settings",
                        icon: "gear",
                        action: {
                            onComplete() // Set flag before opening settings (app may terminate when enabling Full Access)
                            openSettings()
                        }
                    )
                    .padding(.top, 12)

                    OnboardingSecondaryButton(title: "Set Up Later", action: onComplete)
                        .buttonStyle(.plain)

                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .animation(.easeInOut, value: currentPage)
            .animation(.easeInOut, value: permissionState)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            checkMicrophonePermission()
        }
//        .alert("Why Full Access?", isPresented: $showingFullAccessInfo) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text("Full Access allows VivaDicta Keyboard to use the microphone for voice recording. Without it, the keyboard cannot access the microphone.\n\nWe never collect, store, or transmit your keystrokes or personal data. All voice processing happens on your device.")
//        }
    }

    // MARK: - Microphone Permission

    private func checkMicrophonePermission() {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            permissionState = .granted
        case .denied:
            permissionState = .denied
        case .undetermined:
            permissionState = .undetermined
        @unknown default:
            permissionState = .undetermined
        }
    }

    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in
                permissionState = granted ? .granted : .denied
                if granted {
                    // Small delay before continuing
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    withAnimation {
                        currentPage = 2
                    }
                }
            }
        }
    }

    private func openSettings() {
        
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
