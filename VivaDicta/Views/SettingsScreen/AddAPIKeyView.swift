//
//  AddAPIKeyView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI
import AICore

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
            

            if let apiKeyURL = provider.apiKeyURL {
                Button {
                    UIApplication.shared.open(apiKeyURL)
                } label: {
                    Label("Get API Key", systemImage: "key")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
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

            if provider == .ollamaCloud {
                OllamaCloudModelTiersView()
            } else {
                Spacer()
            }
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

    private func deleteAPIKey() {
        HapticManager.heavyImpact()

        // Remove the API key from Keychain
        aiService.deleteAPIKey(for: provider)

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
            isVerifying = true
            verificationError = nil
            
            HapticManager.mediumImpact()
            
            let isValid = await aiService.saveAPIKey(apiKey, for: provider)
            
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

/// Shows which Ollama Cloud models are free with the user's API key versus
/// which require a paid Ollama subscription. Classification lives in AICore
/// (`AIProvider.ollamaCloudFreeModels` / `ollamaCloudSubscriptionModels`).
struct OllamaCloudModelTiersView: View {
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Some Ollama Cloud models are free with your API key. Others need a paid Ollama subscription - choosing one returns a \"requires a subscription\" error.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                OllamaModelTierSection(
                    title: "Free with your key",
                    systemImage: "checkmark.seal.fill",
                    tint: .green,
                    models: AIProvider.ollamaCloudFreeModels,
                    columns: columns
                )

                OllamaModelTierSection(
                    title: "Requires paid subscription",
                    systemImage: "lock.fill",
                    tint: .orange,
                    models: AIProvider.ollamaCloudSubscriptionModels,
                    columns: columns
                )

                Text("The free tier also has usage limits. See ollama.com/upgrade.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }
}

struct OllamaModelTierSection: View {
    let title: String
    let systemImage: String
    let tint: Color
    let models: [String]
    let columns: [GridItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("\(title) (\(models.count))", systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(models, id: \.self) { model in
                    OllamaModelChip(name: model, tint: tint)
                }
            }
        }
    }
}

struct OllamaModelChip: View {
    let name: String
    let tint: Color

    var body: some View {
        Text(name)
            .font(.caption.monospaced())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
            .foregroundStyle(tint)
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

#Preview("Ollama Cloud tiers") {
    NavigationStack {
        AddAPIKeyView(
            provider: .ollamaCloud,
            aiService: AIService(),
            onSave: {_ in })
    }
}
