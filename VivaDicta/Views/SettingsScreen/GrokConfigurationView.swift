// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI
import OAuth
import AICore

/// Grok (xAI) setup: sign in with a SuperGrok / X Premium subscription, or use
/// an API key. Both hit the same `api.x.ai` endpoint - only the bearer differs.
struct GrokConfigurationView: View {
    let aiService: AIService

    @State private var hasExistingKey = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    if let iconName = AIProvider.grok.iconName {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }

                    Text(AIProvider.grok.displayName)
                        .font(.title2)

                    if aiService.connectedProviders.contains(.grok) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(aiService.isGrokSignedIn ? "Subscription Connected" : "API Key Configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                GrokSubscriptionSection(aiService: aiService)

                GrokAPIKeySection(aiService: aiService, hasExistingKey: $hasExistingKey)

                GrokFallbackNote(isSignedIn: aiService.isGrokSignedIn, hasExistingKey: hasExistingKey)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(AIProvider.grok.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasExistingKey = AIProvider.grok.apiKey != nil
        }
    }
}

// MARK: - Subscription Sign-In

/// Drives xAI's device-code sign-in: request a code, send the user to the
/// browser to approve it, then poll until xAI reports the approval.
private struct GrokSubscriptionSection: View {
    let aiService: AIService

    @State private var deviceCode: DeviceCodeResponse?
    @State private var signInTask: Task<Void, Never>?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grok Subscription")
                .font(.headline)

            Text("Use your SuperGrok or X Premium subscription instead of an API key.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Set expectations before the user signs in: xAI gates which plans
            // may connect an app, so a valid subscription can still be refused.
            Label {
                Text("xAI limits which plans can connect an app, so this may not work on every subscription. An API key always works.")
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if aiService.isGrokSignedIn {
                signedInRow
            } else if let deviceCode {
                pendingAuthorization(deviceCode)
            } else {
                signInButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
        .onDisappear {
            signInTask?.cancel()
        }
        .alert("Sign-In Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var signedInRow: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed in")
                    .font(.callout)
                if let email = aiService.grokEmail {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Sign Out", role: .destructive) {
                aiService.signOutFromGrok()
            }
            .controlSize(.small)
        }
    }

    private func pendingAuthorization(_ code: DeviceCodeResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Approve this code at x.ai:")
                .font(.callout)

            Text(code.userCode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            // The opened URI usually carries the code already, so copying is an
            // explicit action - it clobbers the clipboard and shows the system
            // paste banner, which is rude to do on the user's behalf.
            Button("Copy Code", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = code.userCode
                HapticManager.success()
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)

            if let url = URL(string: code.browserURI) {
                Link(destination: url) {
                    Label("Open x.ai to approve", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for approval...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Cancel") {
                signInTask?.cancel()
                deviceCode = nil
            }
            .foregroundStyle(.red)
        }
    }

    private var signInButton: some View {
        Button {
            startSignIn()
        } label: {
            HStack(spacing: 6) {
                if aiService.isGrokSigningIn {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("Sign in with Grok")
                    .font(.headline.weight(.medium))
            }
        }
        .disabled(aiService.isGrokSigningIn)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background {
            Capsule()
                .stroke(.blue, lineWidth: 2)
        }
        .buttonStyle(.plain)
    }

    private func startSignIn() {
        signInTask = Task {
            do {
                let code = try await aiService.startGrokDeviceCodeFlow()
                deviceCode = code

                if let url = URL(string: code.browserURI) {
                    await UIApplication.shared.open(url)
                }

                try await aiService.signInWithGrok(deviceCode: code)
                deviceCode = nil
                HapticManager.success()
            } catch is CancellationError {
                deviceCode = nil
            } catch {
                deviceCode = nil
                // A cancelled request can still surface as a transport error,
                // so don't alert on a sign-in the user walked away from.
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                showError = true
                HapticManager.error()
            }
        }
    }
}

// MARK: - API Key

private struct GrokAPIKeySection: View {
    let aiService: AIService
    @Binding var hasExistingKey: Bool

    @State private var apiKey = ""
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            Text("Billed per token by xAI. Works on any account and unlocks the full model list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let apiKeyURL = AIProvider.grok.apiKeyURL {
                Button {
                    UIApplication.shared.open(apiKeyURL)
                } label: {
                    Label("Get API Key", systemImage: "key")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            TextField("API Key", text: $apiKey)
                .privacySensitive()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background {
                    Capsule()
                        .stroke(verificationError != nil ? .red : .gray, lineWidth: verificationError != nil ? 1.5 : 0.5)
                }
                .onChange(of: apiKey) { _, _ in
                    verificationError = nil
                }

            if let verificationError {
                Text(verificationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button {
                    saveAPIKey()
                } label: {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Save API Key")
                            .font(.headline.weight(.medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background {
                        Capsule()
                            .stroke(.blue, lineWidth: 2)
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
                .buttonStyle(.plain)

                Button {
                    pasteAndSave()
                } label: {
                    Text("Paste")
                        .font(.headline.weight(.medium))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background {
                            Capsule()
                                .stroke(.gray, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
            }

            if hasExistingKey {
                Button {
                    showDeleteConfirmation = true
                    HapticManager.warning()
                } label: {
                    Text("Delete API Key")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .overlay {
                    Capsule()
                        .stroke(.red, lineWidth: 1.5)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
        .onAppear {
            apiKey = AIProvider.grok.apiKey ?? ""
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("Are you sure you want to delete the API key for \(AIProvider.grok.displayName)? This action cannot be undone.")
        }
    }

    private func saveAPIKey() {
        Task {
            isVerifying = true
            verificationError = nil
            HapticManager.mediumImpact()

            let success = await aiService.saveAPIKey(apiKey, for: .grok)
            isVerifying = false
            if success {
                hasExistingKey = true
                HapticManager.success()
            } else {
                verificationError = "Invalid API key"
                HapticManager.error()
            }
        }
    }

    private func pasteAndSave() {
        guard let clipboard = UIPasteboard.general.string else { return }
        let trimmed = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        apiKey = trimmed
        saveAPIKey()
    }

    private func deleteAPIKey() {
        aiService.deleteAPIKey(for: .grok)
        apiKey = ""
        hasExistingKey = false
        aiService.refreshConnectedProviders()
        if !aiService.connectedProviders.contains(.grok) {
            aiService.disableAIEnhancementForModesUsingProvider(.grok)
        }
        HapticManager.success()
    }
}

// MARK: - Fallback Chain

private struct GrokFallbackNote: View {
    let isSignedIn: Bool
    let hasExistingKey: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fallback Chain", systemImage: "arrow.triangle.branch")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                chip("Subscription", isActive: isSignedIn)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                chip("API Key", isActive: hasExistingKey)
            }
            .foregroundStyle(.secondary)

            // Be precise about which failure falls back: a broken token quietly
            // switches to the key, but xAI refusing the plan is reported instead
            // of silently spending API credits.
            Text("If the sign-in cannot be used - the token fails to refresh, for example - the API key is used automatically.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("If xAI refuses the subscription itself, that is reported rather than switched to the API key.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    private func chip(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
            .clipShape(.capsule)
    }
}
