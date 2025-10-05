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
            Text("\(provider.rawValue.capitalized) API Key")
                .font(.title2)
            
            TextField("API Key", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background {
                    Capsule()
                        .strokeBorder(verificationError != nil ? Color.red : Color.black.opacity(0.3), lineWidth: 1.5)
                }
                .onChange(of: apiKey) { _, _ in
                    // Clear error when user starts typing
                    verificationError = nil
                }
            
            if let error = verificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            
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
            
            Spacer()
        }
        .onAppear {
            // Load existing API key if available (needs to be shared with keyboard)
            apiKey = UserDefaultsStorage.shared.string(forKey: Constants.kAPIKeyTemplate + provider.rawValue) ?? ""
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
