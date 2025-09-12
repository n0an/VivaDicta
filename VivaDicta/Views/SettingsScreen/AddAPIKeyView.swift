//
//  AddAPIKeyView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.12
//

import SwiftUI

struct AddAPIKeyView: View {
    let provider: AIProvider
    
    var body: some View {
        VStack {
            Text("Add API Key")
                .font(.title)
                .padding()
            
            Text("for \(provider.rawValue.capitalized)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("API Key")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AddAPIKeyView(provider: .openAI)
    }
}