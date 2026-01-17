//
//  CustomTranscriptionModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.17
//

import SwiftUI

struct CustomTranscriptionModelCard: View {
    let onConfigure: () -> Void

    private var manager: CustomTranscriptionModelManager {
        CustomTranscriptionModelManager.shared
    }

    private var isConfigured: Bool {
        manager.isConfigured
    }

    private var model: CustomTranscriptionModel {
        manager.customModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with name and Custom badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Custom")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    // Model name (if configured)
                    if isConfigured {
                        Text(model.modelName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Info row with icons
                    HStack(spacing: 16) {
                        // Language support
                        Label(
                            isConfigured ? (model.isMultilingual ? "Multilingual" : "English-only") : "Not configured",
                            systemImage: isConfigured ? "globe" : "questionmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                }

                Spacer()

                // Configuration button - gear icon
                Button {
                    HapticManager.lightImpact()
                    onConfigure()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isConfigured ? "checkmark.circle.fill" : "gearshape.circle")
                            .font(.title2)
                            .foregroundStyle(isConfigured ? .green : .blue)
                        Text(isConfigured ? "" : "Configure")
                            .font(.caption2)
                            .foregroundStyle(isConfigured ? .green : .blue)
                    }
                }
                .buttonStyle(.plain)
            }

            // Description
            Text(isConfigured ? "Custom transcription model" : "Add your own OpenAI-compatible transcription API")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.3), lineWidth: 0.5)
        }
        .contentShape(.rect)
        .onTapGesture {
            HapticManager.lightImpact()
            onConfigure()
        }
    }
}

#Preview("Not Configured") {
    VStack(spacing: 20) {
        CustomTranscriptionModelCard(onConfigure: {})
    }
    .padding()
}
