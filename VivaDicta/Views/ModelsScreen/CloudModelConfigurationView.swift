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
    
    var body: some View {
        
        VStack(spacing: 10) {
            Text("\(model.provider.rawValue.capitalized) API Key")
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
                    .foregroundColor(.red)
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
            apiKey = model.apiKey ?? ""
        }
        .padding(.top, 32)
        .padding()
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
}

#Preview {
    CloudModelConfigurationView(
        model: TranscriptionModelProvider.allCloudModels[0],
        onSave: { _ in }
    )
}
