//
//  CloudModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI

struct CloudModelCard: View {
    let model: CloudModel
    let onConfigure: (CloudModel) -> Void

    @State private var selectedTab: TranscriptionModelType = .cloud

    private var isRecommended: Bool {
        // Logic to determine if model is recommended
        model.name.contains("scribe-1") || model.name.contains("whisper-1")
    }

    private var isAPIConfigured: Bool {
        model.apiKey != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with name and badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.provider.rawValue.capitalized)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(model.displayName)
                        .font(.title3)
                        .fontWeight(.regular)
                    Label(model.language, systemImage: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isRecommended {
                    Text("Recommended")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(12)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                // Metrics Section
                VStack(spacing: 8) {
                    ModelMetricRow(
                        label: "Speed",
                        value: Int(model.speed * 10),
                        color: .green
                    )

                    ModelMetricRow(
                        label: "Accuracy",
                        value: Int(model.accuracy * 10),
                        color: .orange
                    )
                }

                Spacer()

                // Cloud model configuration button
                
                    Button(action: {
                        onConfigure(model)
                    }) {
                        VStack(alignment: .center, spacing: 0) {
                            
                            if #available(iOS 26.0, *) {
                                Image(systemName: isAPIConfigured ? "key.circle.fill" : "key.circle")
                                    .foregroundStyle(isAPIConfigured ? .green : .blue)
                                    .font(.system(size: 30))
                            } else {
                                Image(systemName: "key.fill")
                                    .foregroundStyle(isAPIConfigured ? .green : .blue)
                                    .font(.system(size: 16, weight: .bold))
                                    .padding(6)
                                    .background {
                                        Circle()
                                            .stroke(isAPIConfigured ? .green : .blue, lineWidth: 2)
                                    }
                            }
                            
                            if !isAPIConfigured {
                                Text(isAPIConfigured ? "Configured" : "Add API Key")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        
                    }
                    .frame(width: 60)
                    .buttonStyle(.plain)
            }

            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.white)
        .cornerRadius(20)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with unconfigured cloud model
        if let cloudModel = TranscriptionModelProvider.allCloudModels.first {
            CloudModelCard(
                model: cloudModel,
                onConfigure: { _ in print("Configure") }
            )
        }

        // Preview with configured cloud model (simulated)
        if let cloudModel = TranscriptionModelProvider.allCloudModels.last {
            CloudModelCard(
                model: cloudModel,
                onConfigure: { _ in print("Configure") }
            )
        }
    }
    .padding()
    .background(.gray)
}
