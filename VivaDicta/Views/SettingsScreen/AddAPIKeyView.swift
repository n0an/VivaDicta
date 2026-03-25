//
//  AddAPIKeyView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AddAPIKeyView: View {
    @Environment(\.dismiss) var dismiss
    let provider: AIProvider
    let aiService: AIService

    @State private var apiKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verificationError: String? = nil
    @State private var clearButtonVisible = false
    @State private var showDeleteConfirmation = false
    @State private var hasExistingKey = false

    // Claude CLI Server state (Anthropic only)
    @State private var isServerEnabled = UserDefaults.standard.bool(forKey: ClaudeCLIServerClient.isEnabledKey)
    @State private var serverURL = UserDefaults.standard.string(forKey: ClaudeCLIServerClient.serverURLKey) ?? ""
    @State private var serverToken = KeychainService.shared.getString(forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false) ?? ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: Bool?

    var onSave: (AIProvider) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            if let iconName = provider.iconName {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }

            Text("\(provider.displayName) API Key")
                .font(.title2)
            
            
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
                    // Clear error when user starts typing
                    verificationError = nil
                    clearButtonVisible = !apiKey.isEmpty
                }
            
            
            if #available(iOS 26.0, *) {
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            apiKey = trimmed
                            saveKey()
                        }
                    }
                } label: {
                    Text("Paste from clipboard")
                        .font(.headline.weight(.medium))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(.blue.opacity(0.3)).interactive())
                .buttonStyle(.plain)
                .accessibilityLabel("Paste from clipboard")
            } else {
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            apiKey = trimmed
                            saveKey()
                        }
                    }
                } label: {
                    Text("Paste from clipboard")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background {
                            Capsule()
                                .stroke(.blue, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Paste from clipboard")
            }
            

            if clearButtonVisible {
                if #available(iOS 26.0, *) {
                    Button {
                        apiKey = ""
                        HapticManager.lightImpact()
                    } label: {
                        Text("Clear")
                            .font(.headline.weight(.medium))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.gray.opacity(0.3)).interactive())
                    .buttonStyle(.plain)
                } else {
                    Button {
                        apiKey = ""
                        HapticManager.lightImpact()
                    } label: {
                        Text("Clear")
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
            }
            
            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Delete API Key button - only show if there's an existing key
            if hasExistingKey {
                if #available(iOS 26.0, *) {
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
                    .padding(.top, 8)
                } else {
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
                    .padding(.top, 8)
                }
            }

            // Claude CLI Server section (Anthropic only)
            if provider == .anthropic {
                claudeCLIServerSection
            }

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: clearButtonVisible)
        .onAppear {
            // Load existing API key from Keychain (synced via iCloud Keychain)
            let existingKey = provider.apiKey
            apiKey = existingKey ?? ""
            hasExistingKey = existingKey != nil
            clearButtonVisible = !apiKey.isEmpty
        }
        .padding()
        .contentShape(.rect)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isVerifying {
                    ProgressView()
                } else {
                    if #available(iOS 26, *) {
                        Button(role: .confirm) {
                            saveKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(.blue)
                    } else {
                        Button("Save") {
                            saveKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("Are you sure you want to delete the API key for \(provider.displayName)? This action cannot be undone.")
        }
    }

    // MARK: - Claude CLI Server Section

    private var claudeCLIServerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.top, 8)

            Text("Claude CLI Server")
                .font(.headline)

            Text("Use your Claude subscription via a Mac running VivaDicta with Claude CLI. No API key needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Use Claude CLI Server", isOn: $isServerEnabled)
                .onChange(of: isServerEnabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: ClaudeCLIServerClient.isEnabledKey)
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
                    .onChange(of: serverURL) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: ClaudeCLIServerClient.serverURLKey)
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
                    .onChange(of: serverToken) { _, newValue in
                        KeychainService.shared.save(newValue, forKey: ClaudeCLIServerClient.authTokenKeychainKey, syncable: false)
                        connectionTestResult = nil
                    }

                HStack {
                    Button {
                        Task {
                            isTestingConnection = true
                            connectionTestResult = await ClaudeCLIServerClient.testConnection()
                            isTestingConnection = false
                        }
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
        .padding(.horizontal)
    }

    private func deleteAPIKey() {
        HapticManager.heavyImpact()

        // Remove the API key from Keychain
        KeychainService.shared.delete(forKey: provider.keychainKey)

        // Clear the text field and update state
        apiKey = ""
        hasExistingKey = false
        clearButtonVisible = false

        // Refresh connected providers
        aiService.refreshConnectedProviders()

        // Disable AI processing for modes using this provider
        aiService.disableAIEnhancementForModesUsingProvider(provider)

        onSave(provider)
        dismiss()
    }
    
    func saveKey() {
        Task {
            await MainActor.run {
                isVerifying = true
                verificationError = nil
            }
            
            HapticManager.mediumImpact()
            
            let isValid = await aiService.saveAPIKey(apiKey, for: provider)
            
            await MainActor.run {
                isVerifying = false
                
                if isValid {
                    onSave(provider)
                    dismiss()
                } else {
                    verificationError = "Invalid API key. Please check your key and try again."
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddAPIKeyView(
            provider: .openAI,
            aiService: AIService(),
            onSave: {_ in })
    }
}
