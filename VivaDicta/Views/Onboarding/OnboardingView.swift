//
//  OnboardingView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI
import AVFoundation

enum OnboardingPage: Int, CaseIterable, Comparable, Identifiable {
    var id: Self { self }
    case welcome
    case microphone
    case keyboard

    static func < (lhs: OnboardingPage, rhs: OnboardingPage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var previous: OnboardingPage? {
        OnboardingPage(rawValue: rawValue - 1)
    }

    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }
}

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage: OnboardingPage = .welcome
    @State private var isForward = true
    @State private var permissionState: MicrophonePermissionState = .undetermined

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button {
                    if let previous = currentPage.previous {
                        navigateTo(previous)
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .opacity(currentPage > .welcome ? 1 : 0)
                .disabled(currentPage == .welcome)

                Spacer()

                if currentPage == .keyboard {
                    Button("Skip") {
                        onComplete()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .animation(.easeInOut, value: currentPage)

            // Page content (no swipe - button navigation only)
            Group {
                switch currentPage {
                case .welcome:
                    OnboardingWelcomePage()
                case .microphone:
                    OnboardingMicrophonePage(permissionState: $permissionState)
                case .keyboard:
                    OnboardingKeyboardPage()
                }
            }
            .transition(pageTransition)
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom buttons - morph based on current page
            VStack(spacing: 12) {
                switch currentPage {
                case .welcome:
                    // Welcome page - Get Started
                    OnboardingPrimaryButton(title: "Get Started") {
                        navigateTo(.microphone)
                    }

                case .microphone:
                    // Microphone page
                    switch permissionState {
                    case .granted:
                        OnboardingPrimaryButton(
                            title: "Continue",
                            icon: "checkmark.circle.fill",
                            color: .green
                        ) {
                            navigateTo(.keyboard)
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

                case .keyboard:
                    // Keyboard page
                    OnboardingPrimaryButton(
                        title: "Open Settings",
                        icon: "gear",
                        action: {
                            // Set intermediate flag - onboarding will complete on next cold start
                            // This handles the case where app terminates when enabling Full Access
                            UserDefaultsStorage.appPrivate.set(true, forKey: UserDefaultsStorage.Keys.didTapOpenSettingsInOnboarding)
                            openSettings()
                        }
                    )
                    .padding(.top, 12)

                    OnboardingSecondaryButton(title: "Set Up Later", action: onComplete)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .animation(.easeInOut, value: permissionState)

            // Page indicator
            OnboardingPageIndicator(currentPage: currentPage)
                .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            checkMicrophonePermission()
        }
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
                    navigateTo(.keyboard)
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ page: OnboardingPage) {
        HapticManager.selectionChanged()
        isForward = page > currentPage
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage = page
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading),
            removal: .move(edge: isForward ? .leading : .trailing)
        )
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
