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

    // Claude CLI Server state
    @State private var isServerEnabled = UserDefaults.standard.bool(forKey: ClaudeCLIServerClient.isEnabledKey)
    @State private var serverURL = UserDefaults.standard.string(forKey: ClaudeCLIServerClient.serverURLKey) ?? ""
    @State private var serverToken = KeychainService.shared.getString(forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false) ?? ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: Bool?

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
                            Text(isServerEnabled && ClaudeCLIServerClient.isVerified ? "CLI Server Connected" : "API Key Configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // Claude CLI Server section
                cliServerSection

                // API Key section
                apiKeySection
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

            // Show verified status if previously verified
            if isServerEnabled && ClaudeCLIServerClient.isVerified {
                connectionTestResult = true
            }
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

    // MARK: - Claude CLI Server Section

    private var cliServerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude CLI Server")
                .font(.headline)

            Text("Use your Claude subscription via a Mac running VivaDicta with Claude CLI. No API key needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Use Claude CLI Server", isOn: $isServerEnabled)
                .onChange(of: isServerEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: ClaudeCLIServerClient.isEnabledKey)
                    if !newValue {
                        UserDefaults.standard.set(false, forKey: ClaudeCLIServerClient.isVerifiedKey)
                    }
                    connectionTestResult = nil
                    aiService.refreshConnectedProviders()
                }

            if isServerEnabled {
                TextField("Server URL (e.g. http://192.168.1.5:3456)", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onChange(of: serverURL) { _, _ in
                        connectionTestResult = nil
                    }

                SecureField("Auth Token", text: $serverToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background {
                        Capsule()
                            .stroke(.gray, lineWidth: 0.5)
                    }
                    .onChange(of: serverToken) { _, _ in
                        connectionTestResult = nil
                    }

                HStack {
                    Button {
                        saveAndTestConnection()
                    } label: {
                        HStack(spacing: 6) {
                            if isTestingConnection {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(serverURL.isEmpty || isTestingConnection)

                    if let result = connectionTestResult {
                        HStack(spacing: 4) {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result ? .green : .red)
                            Text(result ? "Connected" : "Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
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
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)

                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            apiKey = trimmed
                            saveAPIKey()
                        }
                    }
                } label: {
                    Text("Paste & Save")
                }
            }

            if hasExistingKey {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                    HapticManager.warning()
                } label: {
                    Text("Delete API Key")
                        .font(.subheadline)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.secondary)
        }
    }

    // MARK: - Actions

    private func saveAndTestConnection() {
        UserDefaults.standard.set(serverURL, forKey: ClaudeCLIServerClient.serverURLKey)
        KeychainService.shared.save(serverToken, forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false)

        Task {
            isTestingConnection = true
            let success = await ClaudeCLIServerClient.testConnection()
            connectionTestResult = success
            UserDefaults.standard.set(success, forKey: ClaudeCLIServerClient.isVerifiedKey)
            isTestingConnection = false
            aiService.refreshConnectedProviders()
            if success {
                HapticManager.success()
            } else {
                HapticManager.error()
            }
        }
    }

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
        aiService.disableAIEnhancementForModesUsingProvider(.anthropic)
    }
}

#if DEBUG || QA
#Preview {
    NavigationStack {
        AnthropicConfigurationView(aiService: AIService())
    }
}
#endif
