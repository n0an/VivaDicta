//
//  CloudModelConfigurationView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import SwiftUI

struct CloudModelConfigurationView: View {
    @Environment(\.dismiss) var dismiss
    var model: CloudModel
    var onSave: (CloudModel) -> Void

    @State var apiKey: String = ""
    @State private var isVerifying: Bool = false
    @State private var verificationError: String? = nil
    @State private var aiService = AIService()
    @State private var showDeleteConfirmation: Bool = false
    @State private var clearButtonVisible = false

    var body: some View {
        
        VStack(spacing: 10) {
            if let iconName = model.provider.mappedAIProvider?.iconName {
                Image(iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }

            Text("\(model.provider.displayName) API Key")
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
            if model.apiKey != nil {
                if #available(iOS 26.0, *) {
                    Button(action: {
                        showDeleteConfirmation = true
                        HapticManager.warning()
                    }) {
                        Text("Delete API Key")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.regular.tint(.red.opacity(0.2)).interactive())
                    .padding(.top, 8)
                } else {
                    Button(action: {
                        showDeleteConfirmation = true
                        HapticManager.warning()
                    }) {
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
            apiKey = model.provider.mappedAIProvider?.apiKey ?? ""
            clearButtonVisible = !apiKey.isEmpty
        }
        .padding()
        .alert("Delete API Key", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
        } message: {
            Text("Are you sure you want to delete the API key for \(model.provider.rawValue.capitalized)? This action cannot be undone.")
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
    }
    
    
    func saveKey() {
        Task {
            guard let aiProvider = model.provider.mappedAIProvider else {
                await MainActor.run {
                    verificationError = "API verification not supported for this provider"
                }
                return
            }
            
            await MainActor.run {
                isVerifying = true
                verificationError = nil
            }
            
            HapticManager.mediumImpact()
            
            let isValid = await aiService.saveAPIKey(apiKey, for: aiProvider)
            
            await MainActor.run {
                isVerifying = false

                if isValid {
                    onSave(model)
                } else {
                    verificationError = "Invalid API key. Please check your key and try again."
                }
            }
        }
    }

    func deleteAPIKey() {
        HapticManager.heavyImpact()
        // Remove the API key from Keychain
        if let aiProvider = model.provider.mappedAIProvider {
            KeychainService.shared.delete(forKey: aiProvider.keychainKey)
        }

        // Clear the text field
        apiKey = ""

        // Refresh AI service if applicable
        if model.provider.mappedAIProvider != nil {
            aiService.refreshConnectedProviders()
        }

        // Notify parent view to refresh
        onSave(model)
    }
}

#Preview {
    CloudModelConfigurationView(
        model: TranscriptionModelProvider.allCloudModels[0],
        onSave: { _ in }
    )
}
