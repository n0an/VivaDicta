//
//  AnthropicConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.26
//

import SwiftUI

struct AnthropicConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    let aiService: AIService

    // API Key state
    @State private var apiKey: String = ""
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var hasExistingKey = false
    @State private var showDeleteConfirmation = false
    @State private var isClaudeCliEnabled = VivAgentsClient.isClaudeCliEnabled


    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let iconName = AIProvider.anthropic.iconName {
                        Image(iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                    }

                    Text("Anthropic")
                        .font(.title2)

                    if aiService.connectedProviders.contains(.anthropic) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(VivAgentsClient.isEnabled && VivAgentsClient.isClaudeCliActive ? "VivAgents Server Connected" : "API Key Configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // VivAgents Server section
                cliServerStatusSection

                // API Key section
                apiKeySection

                // Fallback chain
                fallbackChainNote
            }
            .padding()
        }
        .contentShape(.rect)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Anthropic")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let existingKey = AIProvider.anthropic.apiKey
            apiKey = existingKey ?? ""
            hasExistingKey = existingKey != nil
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("Are you sure you want to delete the API key for Anthropic? This action cannot be undone.")
        }
    }

    // MARK: - VivAgents Server Status Section

    private var cliServerStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude CLI Agent")
                .font(.headline)

            if VivAgentsClient.isEnabled && VivAgentsClient.isClaudeCliAvailable {
                Toggle("Use Claude CLI Agent", isOn: $isClaudeCliEnabled)
                    .onChange(of: isClaudeCliEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: VivAgentsClient.claudeCliEnabledKey)
                        aiService.refreshConnectedProviders()
                    }

                if isClaudeCliEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Claude CLI active")
                            .font(.callout)
                    }
                }
            } else {
                Text("Use your Claude subscription via the VivAgents Server. No API key needed.")
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

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            Text("Or use an Anthropic API key directly.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                        if let clipboardString = UIPasteboard.general.string {
                            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                apiKey = trimmed
                                saveAPIKey()
                            }
                        }
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
                        if let clipboardString = UIPasteboard.general.string {
                            let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                apiKey = trimmed
                                saveAPIKey()
                            }
                        }
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
                Text("VivAgents")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VivAgentsClient.isEnabled && VivAgentsClient.isVerified ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
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

    // MARK: - Actions

    private func saveAPIKey() {
        Task {
            isVerifying = true
            verificationError = nil
            HapticManager.mediumImpact()

            let isValid = await aiService.saveAPIKey(apiKey, for: .anthropic)

            isVerifying = false
            if isValid {
                hasExistingKey = true
                HapticManager.success()
            } else {
                verificationError = "Invalid API key. Please check your key and try again."
                HapticManager.error()
            }
        }
    }

    private func deleteAPIKey() {
        HapticManager.heavyImpact()
        KeychainService.shared.delete(forKey: AIProvider.anthropic.keychainKey)
        apiKey = ""
        hasExistingKey = false
        aiService.refreshConnectedProviders()
        // Only disable modes if VivAgents Server isn't keeping Anthropic connected
        if !aiService.connectedProviders.contains(.anthropic) {
            aiService.disableAIEnhancementForModesUsingProvider(.anthropic)
        }
    }
}

#if DEBUG || QA
#Preview {
    NavigationStack {
        AnthropicConfigurationView(aiService: AIService())
    }
}
#endif
