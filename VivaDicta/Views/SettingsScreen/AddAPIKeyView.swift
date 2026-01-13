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
    
    var onSave: (AIProvider) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
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
                }
            
            
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

            if !apiKey.isEmpty {
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

            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
            if #available(iOS 26.0, *) {
                Button(action: saveKey) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(isVerifying ? "Verifying..." : "Save")
                            .font(.headline.weight(.semibold))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .glassEffect(.regular.tint(.blue.opacity(0.7)).interactive())
                .foregroundStyle(.white)
                .padding(.top, 16)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
                
            } else {
                Button(action: saveKey) {
                    HStack {
                        if isVerifying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        }
                        Text(isVerifying ? "Verifying..." : "Save")
                            .font(.headline.weight(.semibold))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .foregroundStyle(.white)
                .background(.blue, in: .capsule)
                .padding(.top, 16)
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
            }
            
            Spacer()
        }
        .onAppear {
            // Load existing API key if available (needs to be shared with keyboard)
            apiKey = UserDefaultsStorage.shared.string(forKey: AppGroupCoordinator.kAPIKeyTemplate + provider.rawValue) ?? ""
        }
        .padding(.top, 32)
        .padding()
        .navigationBarTitleDisplayMode(.inline)
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
