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
    let onDeleteAPIKey: ((CloudModel) -> Void)?

    @State private var selectedTab: TranscriptionModelType = .cloud
    @State private var showDeleteAlert = false

    private var isAPIConfigured: Bool {
        model.apiKey != nil
    }

    private var speedColor: Color {
        if model.speed >= 0.75 {
            return .green  // good
        } else if model.speed >= 0.6 {
            return .orange  // medium
        } else {
            return .red  // bad
        }
    }

    private var accuracyColor: Color {
        if model.accuracy >= 0.75 {
            return .green  // good
        } else if model.accuracy >= 0.6 {
            return .orange  // medium
        } else {
            return .red  // bad
        }
    }

    private var costColor: Color {
        // Cost is reversed - lower is better
        if model.cost < 0.6 {
            return .green  // good (cheap)
        } else if model.cost < 0.75 {
            return .orange  // medium
        } else {
            return .red  // bad (expensive)
        }
    }

    var body: some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.provider.displayName)
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
                                    .contentTransition(.symbolEffect(.replace))
                                    .foregroundStyle(isAPIConfigured ? .green : .blue)
                                    .font(.system(size: 30))
                            } else {
                                Image(systemName: "key.fill")
                                    .contentTransition(.symbolEffect(.replace))
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
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .shadow(color: .primary.opacity(0.5), radius: 2, x: 2, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.3), lineWidth: 0.5)
        }
        .contextMenu {
            if isAPIConfigured {
                Button(role: .destructive) {
                    HapticManager.warning()
                    showDeleteAlert = true
                } label: {
                    Label("Delete API Key", systemImage: "key.slash")
                }
            }
        }
        .alert("Delete Model", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete the API key for \(model.provider.rawValue.capitalized)? This action cannot be undone.")
        }
    }

    private func deleteAPIKey() {
        HapticManager.heavyImpact()

        // Remove the API key from UserDefaults
        let keyName = AppGroupCoordinator.kAPIKeyTemplate + model.provider.rawValue
        UserDefaultsStorage.shared.removeObject(forKey: keyName)

        // Notify parent view about the deletion
        onDeleteAPIKey?(model)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Preview with unconfigured cloud model
        if let cloudModel = TranscriptionModelProvider.allCloudModels.first {
            CloudModelCard(
                model: cloudModel,
                onConfigure: { _ in print("Configure") },
                onDeleteAPIKey: { _ in print("Delete API Key") }
            )
        }

        // Preview with configured cloud model (simulated)
        if let cloudModel = TranscriptionModelProvider.allCloudModels.last {
            CloudModelCard(
                model: cloudModel,
                onConfigure: { _ in print("Configure") },
                onDeleteAPIKey: { _ in print("Delete API Key") }
            )
        }
    }
    .padding()
//    .background(.gray)
}
