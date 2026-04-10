//
//  ChatToolsSettingsView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI

/// Settings view for configuring chat tools (web search, etc.)
/// that Apple FM can use during chat conversations.
struct ChatToolsSettingsView: View {
    @State private var exaAPIKey: String = ""
    @State private var hasExistingKey = false
    @State private var showDeleteConfirmation = false
    @State private var isVerifying = false
    @State private var verificationError: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When chatting with Apple Foundation Models, tools give the AI the ability to search the web for current information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Exa API Key", text: $exaAPIKey)
                    .privacySensitive()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: exaAPIKey) { _, _ in
                        verificationError = nil
                    }

                if let error = verificationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    saveKey()
                } label: {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isVerifying ? "Verifying..." : "Save")
                    }
                }
                .disabled(exaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)

                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            exaAPIKey = trimmed
                            saveKey()
                        }
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                }

                Link(destination: URL(string: "https://dashboard.exa.ai/api-keys")!) {
                    Label("Get Exa API Key", systemImage: "key")
                }

                if hasExistingKey {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete API Key", systemImage: "trash")
                    }
                }
            } header: {
                Text("Web Search (Exa)")
            } footer: {
                Text("Exa provides web search results to Apple FM during chat. Only used with Apple Foundation Models provider.")
            }
        }
        .navigationTitle("Chat Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let existing = ExaAPIKeyManager.apiKey
            exaAPIKey = existing ?? ""
            hasExistingKey = existing != nil
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                ExaAPIKeyManager.delete()
                exaAPIKey = ""
                hasExistingKey = false
                HapticManager.heavyImpact()
            }
        } message: {
            Text("Are you sure you want to delete the Exa API key?")
        }
    }

    private func saveKey() {
        let trimmed = exaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isVerifying = true
        verificationError = nil

        Task {
            let isValid = await verifyExaKey(trimmed)

            isVerifying = false

            if isValid {
                ExaAPIKeyManager.save(trimmed)
                hasExistingKey = true
                HapticManager.success()
            } else {
                verificationError = "Invalid API key. Please check your key and try again."
                HapticManager.error()
            }
        }
    }

    private func verifyExaKey(_ key: String) async -> Bool {
        guard let url = URL(string: "https://api.exa.ai/search") else { return false }

        let payload: [String: Any] = ["query": "test", "numResults": 1]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}
