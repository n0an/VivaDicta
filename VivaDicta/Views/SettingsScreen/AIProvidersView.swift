//
//  AIProvidersView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.14
//

import SwiftUI

struct AIProviders: View {
    var body: some View {
        List {
            if AppleFoundationModelAvailability.isAvailable {
                Section("On-Device") {
                    Text(AIProvider.apple.displayName)
                }
            }

            Section("Cloud") {
                ForEach(AIProvider.cloudProviders) { provider in
                    Text(provider.displayName)
                }
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        AIProviders()
    }
}
