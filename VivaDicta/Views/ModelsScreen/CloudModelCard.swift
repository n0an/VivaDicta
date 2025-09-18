//
//  CloudModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import SwiftUI

struct CloudModelCard: View {
    private var model: CloudModel
    private var onConfigure: (CloudModel) -> Void
    
    private var isAPIConfigured: Bool {
        model.apiKey != nil
    }
    
    init(model: CloudModel,
         onConfigure: @escaping (CloudModel) -> Void) {
        self.model = model
        self.onConfigure = onConfigure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    metadataSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                actionSection
            }
            descriptionSection
        }
        .padding(16)
        .background(.gray.opacity(0.1), in: .rect(cornerRadius: 16))
    }
    
    private var header: some View {
        HStack {
            Text(model.displayName)
                .font(.headline.weight(.semibold))
            statusBadge
            Spacer()
        }
    }
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Text(model.provider.rawValue.capitalized)
                    Image(systemName: "cloud")
                }
                
                HStack(spacing: 4) {
                    Text(model.language)
                    Image(systemName: "globe")
                }
            }
            .foregroundStyle(.secondary)
            .font(.caption)
            
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.accuracy * 10)
            }
        }
    }
    
    private var statusBadge: some View {
        Group {
            if !isAPIConfigured {
                Text("Add API key")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange, in: .rect(cornerRadius: 16))
            }
        }
    }
    
    private var descriptionSection: some View {
        Text(model.description)
            .multilineTextAlignment(.leading)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
    
    private var actionSection: some View {
        VStack {
            configureButton
        }
        .font(.callout.weight(.semibold))
    }
    
    var configureButton: some View {
        Button {
            onConfigure(model)
        } label: {
            HStack(spacing: 4) {
                Text("Configure")
                Image(systemName: "gear")
            }
        }

        .foregroundStyle(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.blue, in: .capsule)
    }
}

#Preview {
    CloudModelCard(
        model: TranscriptionModelProvider.allCloudModels[0],
        onConfigure: {_ in print("configure") }
    )
}

