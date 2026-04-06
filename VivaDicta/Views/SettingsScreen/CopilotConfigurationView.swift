// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

struct CopilotConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    @State private var deviceCode: DeviceCodeResponse?
    @State private var pollingTask: Task<Void, Never>?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let iconName = AIProvider.copilot.iconName {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }

                    Text("GitHub Copilot")
                        .font(.title2)

                    if aiService.isCopilotSignedIn {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // GitHub Account section
                accountSection
            }
            .padding()
        }
        .navigationTitle("GitHub Copilot")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            pollingTask?.cancel()
        }
        .alert("Sign-In Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GitHub Account")
                .font(.headline)

            Text("Access Anthropic, GPT, Gemini models via your Copilot account.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if aiService.isCopilotSignedIn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in")
                            .font(.callout)
                        if let username = aiService.copilotUsername {
                            Text("@\(username)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Sign Out", role: .destructive) {
                        aiService.signOutFromCopilot()
                    }
                    .controlSize(.small)
                }
            } else if let code = deviceCode {
                // Device code displayed — waiting for user to authorize
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter this code at GitHub:")
                        .font(.callout)

                    Text(code.userCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)

                    if let url = URL(string: code.verificationUri) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open github.com/login/device")
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Waiting for authorization...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Cancel") {
                        pollingTask?.cancel()
                        deviceCode = nil
                    }
                    .foregroundStyle(.red)
                }
            } else {
                if #available(iOS 26.0, *) {
                    Button {
                        startCopilotSignIn()
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isCopilotSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sign in with GitHub")
                                .font(.headline.weight(.medium))
                        }
                    }
                    .disabled(aiService.isCopilotSigningIn)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                    .buttonStyle(.plain)
                } else {
                    Button {
                        startCopilotSignIn()
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isCopilotSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sign in with GitHub")
                                .font(.headline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background {
                            Capsule()
                                .stroke(.blue, lineWidth: 2)
                        }
                    }
                    .disabled(aiService.isCopilotSigningIn)
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    // MARK: - Actions

    private func startCopilotSignIn() {
        pollingTask = Task {
            do {
                let code = try await CopilotOAuthManager.shared.startDeviceCodeFlow()
                self.deviceCode = code

                // Copy code to clipboard
                UIPasteboard.general.string = code.userCode

                // Open browser
                if let url = URL(string: code.verificationUri) {
                    await UIApplication.shared.open(url)
                }

                // Poll for authorization
                try await aiService.signInWithCopilot(deviceCode: code)
                self.deviceCode = nil
            } catch {
                self.deviceCode = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
