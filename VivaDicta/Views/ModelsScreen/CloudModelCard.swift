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

    private var isAPIConfigured: Bool {
        model.apiKey != nil
    }

    // MARK: - Metric Colors

    /// Returns color based on metric value (higher is better)
    private func metricColor(for value: Double, highThreshold: Double = 0.75, mediumThreshold: Double = 0.6) -> Color {
        if value >= highThreshold {
            return .green  // good
        } else if value >= mediumThreshold {
            return .orange  // medium
        } else {
            return .red  // bad
        }
    }

    /// Returns color based on cost (lower is better - inverted scale)
    private func costMetricColor(for value: Double, lowThreshold: Double = 0.6, mediumThreshold: Double = 0.75) -> Color {
        if value < lowThreshold {
            return .green  // good (cheap)
        } else if value < mediumThreshold {
            return .orange  // medium
        } else {
            return .red  // bad (expensive)
        }
    }

    private var speedColor: Color {
        metricColor(for: model.speed)
    }

    private var accuracyColor: Color {
        metricColor(for: model.accuracy)
    }

    private var costColor: Color {
        costMetricColor(for: model.cost)
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
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
                    if model.recommended {
                        Text("Recommended")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                    }
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
            
            VStack(alignment: .leading, spacing: 8) {
                ModelMetricRow(
                    label: "Speed",
                    value: model.speed * 10,
                    color: speedColor
                )

                ModelMetricRow(
                    label: "Accuracy",
                    value: model.accuracy * 10,
                    color: accuracyColor
                )

                ModelMetricRow(
                    label: "Cost",
                    value: model.cost * 10,
                    color: costColor
                )
            }

            // Description
            Text(model.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.3), lineWidth: 0.5)
        }
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
//    .background(.gray)
}
