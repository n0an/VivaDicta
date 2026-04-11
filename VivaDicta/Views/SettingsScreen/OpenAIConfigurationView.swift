// Copyright © 2026 Anton Novoselov. All rights reserved.

import SwiftUI

struct OpenAIConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    // API Key state
    @State private var apiKey: String = ""
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var hasExistingKey = false
    @State private var showDeleteConfirmation = false
    @State private var isCodexCliEnabled = VivAgentsClient.isCodexCliEnabled
    // OAuth error
    @State private var showOAuthError = false
    @State private var oauthErrorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let iconName = AIProvider.openAI.iconName {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }

                    Text("OpenAI")
                        .font(.title2)

                    if aiService.connectedProviders.contains(.openAI) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(openAIConnectionLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // Model availability note
                modelAvailabilityNote

                // OpenAI OAuth section
                openAIOAuthSection

                // CLI Server section
                cliServerSection

                // API Key section
                apiKeySection

                // Fallback chain
                fallbackChainNote
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("OpenAI")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let existingKey = AIProvider.openAI.apiKey
            apiKey = existingKey ?? ""
            hasExistingKey = existingKey != nil
        }
        .alert("Sign-In Error", isPresented: $showOAuthError) {
            Button("OK") {}
        } message: {
            Text(oauthErrorMessage)
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("Are you sure you want to delete the API key for OpenAI? This action cannot be undone.")
        }
    }

    // MARK: - Model Availability Note

    private var modelAvailabilityNote: some View {
        Label {
            Text("OAuth and CLI agent connections support a limited set of models. Use an API key for full model access.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - OpenAI OAuth Section

    private var openAIOAuthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI OAuth")
                .font(.headline)

            Text("Use your OpenAI Plus/Pro account — no API key needed. May have rate limits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if aiService.isOpenAISignedIn {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in")
                            .font(.callout)
                        if let email = aiService.openAIEmail {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Sign Out", role: .destructive) {
                        aiService.signOutFromOpenAI()
                    }
                    .controlSize(.small)
                }
            } else {
                if #available(iOS 26.0, *) {
                    Button {
                        signInWithOpenAI()
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isOpenAISigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sign in with OpenAI")
                                .font(.headline.weight(.medium))
                        }
                    }
                    .disabled(aiService.isOpenAISigningIn)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                    .buttonStyle(.plain)
                } else {
                    Button {
                        signInWithOpenAI()
                    } label: {
                        HStack(spacing: 6) {
                            if aiService.isOpenAISigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sign in with OpenAI")
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
                    .disabled(aiService.isOpenAISigningIn)
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

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            Text("Fastest and most reliable option. No rate limits.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let apiKeyURL = AIProvider.openAI.apiKeyURL {
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

            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if #available(iOS 26.0, *) {
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
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                    .buttonStyle(.plain)

                    Button {
                        pasteAndSave()
                    } label: {
                        Text("Paste")
                            .font(.headline.weight(.medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.gray.opacity(0.3)).interactive())
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
                    .glassEffect(.regular.tint(.red.opacity(0.2)).interactive())
                    .padding(.top, 4)
                }
            } else {
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
                                .foregroundStyle(.primary)
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
                            .foregroundStyle(.primary)
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
                            .stroke(Color.red, lineWidth: 1.5)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    // MARK: - Fallback Chain

    private var fallbackChainNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fallback Chain", systemImage: "arrow.triangle.branch")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text("OAuth")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(aiService.isOpenAISignedIn ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(.capsule)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("VivAgents")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(.capsule)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("API Key")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(hasExistingKey ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .clipShape(.capsule)
            }
            .foregroundStyle(.secondary)

            Text("If the first available method fails, the next one is tried automatically.")
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

    // MARK: - CLI Server Section

    private var openAIConnectionLabel: String {
        if aiService.isOpenAISignedIn {
            return "OAuth Connected"
        } else if VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliActive {
            return "VivAgents Server Connected"
        } else {
            return "API Key Configured"
        }
    }

    private var cliServerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Codex CLI Agent")
                .font(.headline)

            if VivAgentsClient.isEnabled && VivAgentsClient.isCodexCliAvailable {
                Toggle("Use Codex CLI Agent", isOn: $isCodexCliEnabled)
                    .onChange(of: isCodexCliEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: VivAgentsClient.codexCliEnabledKey)
                        aiService.refreshConnectedProviders()
                    }

                if isCodexCliEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Codex CLI active")
                            .font(.callout)
                    }
                }
            } else {
                Text("Use your OpenAI Codex CLI account via the VivAgents Server. No API key needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    CLIServerConfigurationView(aiService: aiService)
                } label: {
                    Text("Configure VivAgents Server")
                        .font(.callout)
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

    private func signInWithOpenAI() {
        Task {
            do {
                try await aiService.signInWithOpenAI()
            } catch {
                oauthErrorMessage = error.localizedDescription
                showOAuthError = true
            }
        }
    }

    private func saveAPIKey() {
        Task {
            isVerifying = true
            verificationError = nil
            HapticManager.mediumImpact()

            let success = await aiService.saveAPIKey(apiKey, for: .openAI)
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
        if let clipboardString = UIPasteboard.general.string {
            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                apiKey = trimmed
                saveAPIKey()
            }
        }
    }

    private func deleteAPIKey() {
        KeychainService.shared.delete(forKey: AIProvider.openAI.keychainKey)
        apiKey = ""
        hasExistingKey = false
        aiService.refreshConnectedProviders()
        if !aiService.connectedProviders.contains(.openAI) {
            aiService.disableAIEnhancementForModesUsingProvider(.openAI)
        }
        HapticManager.success()
    }
}
