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
    var onSave: (CloudModel, String) -> Void
    
    @State var apiKey: String = ""
    
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
                        .strokeBorder(Color.black.opacity(0.3), lineWidth: 1.5)
                }
             
            Button(action: saveKey) {
                Text("Save")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(.blue, in: .capsule)
            .padding(.top, 16)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
        }
        .padding(.top, 32)
        .padding()
    }
    
    
    func saveKey() {
        onSave(model, apiKey)
//        dismiss()
    }
    
}

#Preview {
    CloudModelConfigurationView(
        model: TranscriptionModelProvider.allCloudModels[0],
        onSave: {_, _ in }
        )
}
