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
            
            if UIPasteboard.general.hasStrings {
                if #available(iOS 26.0, *) {
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            apiKey = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                            HapticManager.lightImpact()
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
                            apiKey = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                            HapticManager.lightImpact()
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

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: clearButtonVisible)
        .onAppear {
            // Load existing API key if available (needs to be shared with keyboard)
            let existingKey = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue)
            apiKey = existingKey ?? ""
            hasExistingKey = existingKey != nil
            clearButtonVisible = !apiKey.isEmpty
        }
        .padding()
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

    private func deleteAPIKey() {
        HapticManager.heavyImpact()

        // Remove the API key from UserDefaults
        let keyName = AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue
        UserDefaultsStorage.shared.removeObject(forKey: keyName)

        // Clear the text field and update state
        apiKey = ""
        hasExistingKey = false
        clearButtonVisible = false

        // Refresh connected providers
        aiService.refreshConnectedProviders()

        // Disable AI enhancement for modes using this provider
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
