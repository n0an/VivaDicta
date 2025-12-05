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
    @State private var isForward = true
    @State private var permissionState: MicrophonePermissionState = .undetermined

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button {
                    navigateTo(currentPage - 1)
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

            // Page content (no swipe - button navigation only)
            Group {
                switch currentPage {
                case 0:
                    OnboardingWelcomePage()
                case 1:
                    OnboardingMicrophonePage(permissionState: $permissionState)
                case 2:
                    OnboardingKeyboardPage()
                default:
                    OnboardingWelcomePage()
                }
            }
            .transition(pageTransition)
            .animation(.easeInOut(duration: 0.3), value: currentPage)

            // Bottom buttons - morph based on current page
            VStack(spacing: 12) {
                switch currentPage {
                case 0:
                    // Welcome page - Get Started
                    OnboardingPrimaryButton(title: "Get Started") {
                        navigateTo(1)
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
                            navigateTo(2)
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
                            // Set intermediate flag - onboarding will complete on next cold start
                            // This handles the case where app terminates when enabling Full Access
                            UserDefaultsStorage.appPrivate.set(true, forKey: "didTapOpenSettingsInOnboarding")
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
            .padding(.bottom, 12)
            .animation(.easeInOut, value: permissionState)

            // Page indicator
            OnboardingPageIndicator(currentPage: currentPage, totalPages: 3)
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
                    navigateTo(2)
                }
            }
        }
    }

    // MARK: - Navigation

    private func navigateTo(_ page: Int) {
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
