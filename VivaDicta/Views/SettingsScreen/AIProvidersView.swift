//
//  AIProvidersView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.14
//

import SwiftUI

struct AIProviders: View {
    @Environment(AppState.self) private var appState

    @State private var providerToConfigure: AIProvider?

    var body: some View {
        List {
            if AppleFoundationModelAvailability.isAvailable {
                Section("On-Device") {
                    Text(AIProvider.apple.displayName)
                }
            }

            Section("Cloud") {
                ForEach(AIProvider.cloudProviders) { provider in
                    Button {
                        providerToConfigure = provider
                    } label: {
                        HStack {
                            Text(provider.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if !provider.hasAPIKey {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Add API Key")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("AI Providers")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $providerToConfigure) { provider in
            AddAPIKeyView(
                provider: provider,
                aiService: appState.aiService,
                onSave: { _ in
                    providerToConfigure = nil
                }
            )
        }
    }
}

#Preview {
    NavigationStack {
        AIProviders()
    }
}
