//
//  CloudModelCard.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import SwiftUI

struct CloudModelCard: View {
    private var model: CloudModel
    private var onSelect: (CloudModel) -> Void
    private var onConfigure: (CloudModel) -> Void
    private var isSelected: Bool
    
    private var isAPIConfigured: Bool {
        model.apiKey != nil
    }
    
    init(model: CloudModel,
         isSelected: Bool,
         onConfigure: @escaping (CloudModel) -> Void,
         onSelect: @escaping (CloudModel) -> Void) {
        self.model = model
        self.isSelected = isSelected
        self.onConfigure = onConfigure
        self.onSelect = onSelect
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
        .background(isSelected ? Color(UIColor.blue.withAlphaComponent(0.1)) : .white, in: .rect(cornerRadius: 16))
    }
    
    private var header: some View {
        HStack {
            Text(model.displayName)
                .font(.system(size: 16, weight: .semibold))
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
            .font(.system(size: 11))
            
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                ModelPerformanceStatsDots(value: model.accuracy * 10)
            }
        }
    }
    
    private var statusBadge: some View {
        Group {
            if !isAPIConfigured {
                Text("Add API key")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange, in: .rect(cornerRadius: 16))
            }
        }
    }
    
    private var descriptionSection: some View {
        Text(model.description)
            .multilineTextAlignment(.leading)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
    
    private var actionSection: some View {
        VStack {
            if isAPIConfigured {
                if isSelected {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Selected")
                    }
                    .foregroundStyle(.green)
                    
                } else {
                    selectButton
                }
            } else {
                configureButton
            }
        }
    }
    
    var selectButton: some View {
        Button("Select") {
            onSelect(model)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(.blue, in: .capsule)
    }
    
    var configureButton: some View {
        Button {
            onConfigure(model)
        } label: {
            HStack(spacing: 4) {
                Text("Configure")
                Image(systemName: "gear")
            }
            .font(.system(size: 12, weight: .semibold))
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
        isSelected: false,
        onConfigure: {_ in print("configure") },
        onSelect: {_ in print("select") }
    )
}

