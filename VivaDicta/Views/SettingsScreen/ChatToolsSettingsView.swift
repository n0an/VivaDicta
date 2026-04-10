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
    @State private var clearButtonVisible = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Web Search (Exa)")
                .font(.title2)

            Text("Give Apple FM the ability to search the web for current information during chat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Exa API Key", text: $exaAPIKey)
                .privacySensitive()
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background {
                    Capsule()
                        .stroke(verificationError != nil ? .red : .gray, lineWidth: verificationError != nil ? 1.5 : 0.5)
                }
                .onChange(of: exaAPIKey) { _, _ in
                    verificationError = nil
                    clearButtonVisible = !exaAPIKey.isEmpty
                }

            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            if #available(iOS 26.0, *) {
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            exaAPIKey = trimmed
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
            } else {
                Button {
                    if let clipboardString = UIPasteboard.general.string {
                        let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            exaAPIKey = trimmed
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
            }

            Button {
                UIApplication.shared.open(URL(string: "https://dashboard.exa.ai/api-keys")!)
            } label: {
                Label("Get Exa API Key", systemImage: "key")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if clearButtonVisible {
                if #available(iOS 26.0, *) {
                    Button {
                        exaAPIKey = ""
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
                        exaAPIKey = ""
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

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: clearButtonVisible)
        .padding()
        .contentShape(.rect)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .navigationTitle("Chat Tools")
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
                        .disabled(exaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .tint(.blue)
                    } else {
                        Button("Save") {
                            saveKey()
                        }
                        .disabled(exaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            let existing = ExaAPIKeyManager.apiKey
            exaAPIKey = existing ?? ""
            hasExistingKey = existing != nil
            clearButtonVisible = !exaAPIKey.isEmpty
        }
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                ExaAPIKeyManager.delete()
                exaAPIKey = ""
                hasExistingKey = false
                clearButtonVisible = false
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
            HapticManager.mediumImpact()

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
