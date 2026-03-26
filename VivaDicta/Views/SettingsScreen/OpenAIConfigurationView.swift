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
                            Text(aiService.isChatGPTSignedIn ? "ChatGPT Connected" : "API Key Configured")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                // ChatGPT OAuth section
                chatGPTSection

                // API Key section
                apiKeySection
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
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the stored API key.")
        }
    }

    // MARK: - ChatGPT OAuth Section

    private var chatGPTSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ChatGPT Account", systemImage: "person.badge.key")
                .font(.headline)

            VStack(spacing: 12) {
                if aiService.isChatGPTSignedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in")
                                .font(.callout)
                            if let email = aiService.chatGPTEmail {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Sign Out", role: .destructive) {
                            aiService.signOutFromChatGPT()
                        }
                        .controlSize(.small)
                    }

                    Text("Using your ChatGPT subscription for AI processing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        Task {
                            do {
                                try await aiService.signInWithChatGPT()
                            } catch {
                                oauthErrorMessage = error.localizedDescription
                                showOAuthError = true
                            }
                        }
                    } label: {
                        HStack {
                            if aiService.isChatGPTSigningIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: "person.badge.key")
                            Text("Sign in with ChatGPT")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(aiService.isChatGPTSigningIn)

                    Text("Use your ChatGPT Plus/Pro subscription — no API key needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Key", systemImage: "key")
                .font(.headline)

            VStack(spacing: 12) {
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
                        if let clipboardString = UIPasteboard.general.string {
                            apiKey = clipboardString
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }

                    Spacer()

                    if hasExistingKey {
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }

                    Button {
                        Task {
                            isVerifying = true
                            verificationError = nil
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
                    } label: {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty || isVerifying)
                }

                Text("Alternative: use an OpenAI API key for direct API access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func deleteAPIKey() {
        KeychainService.shared.delete(forKey: AIProvider.openAI.keychainKey)
        apiKey = ""
        hasExistingKey = false
        aiService.refreshConnectedProviders()
        HapticManager.success()
    }
}
