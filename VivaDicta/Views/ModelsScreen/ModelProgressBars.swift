//
//  ModelProgressBars.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI

struct ModelProgressBars: View {
    let value: Double // 0-10 scale (supports fractional values)
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<10) { index in
                let indexDouble = Double(index)
                let fillAmount: Double = {
                    if value >= indexDouble + 1 {
                        return 1.0  // Fully filled
                    } else if value > indexDouble {
                        return value - indexDouble  // Partially filled
                    } else {
                        return 0.0  // Empty
                    }
                }()

                ZStack(alignment: .leading) {
                    // Background (gray)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 12, height: 6)

                    // Foreground (colored) - only show if there's fill
                    if fillAmount > 0 {
                        Rectangle()
                            .fill(color)
                            .frame(width: 12 * fillAmount, height: 6)
                    }
                }
                .cornerRadius(1)
            }
        }
    }
}

struct ModelMetricRow: View {
    let label: String
    let value: Double // 0-10 scale (supports fractional values)
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            ModelProgressBars(value: value, color: color)

            Text(value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))/10" : "\(value.formatted(.number.precision(.fractionLength(1))))/10")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// Capability ticks shown under a model's metric rows. Only the capabilities the
/// model actually has are drawn, so a model without either shows nothing.
struct ModelCapabilityBadges: View {
    let supportsSpeakerDiarization: Bool
    let supportsNativeTranslation: Bool

    var body: some View {
        if supportsSpeakerDiarization || supportsNativeTranslation {
            HStack(spacing: 16) {
                if supportsSpeakerDiarization {
                    ModelCapabilityBadge(title: "Speaker Labels")
                }
                if supportsNativeTranslation {
                    ModelCapabilityBadge(title: "Native Translation")
                }
            }
        }
    }
}

struct ModelCapabilityBadge: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.green)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Supports \(title)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ModelMetricRow(label: "Speed", value: 9.5, color: .green)
        ModelMetricRow(label: "Accuracy", value: 6.3, color: .orange)
        ModelMetricRow(label: "Cost", value: 2.7, color: .red)
        ModelCapabilityBadges(supportsSpeakerDiarization: true, supportsNativeTranslation: true)
        ModelCapabilityBadges(supportsSpeakerDiarization: true, supportsNativeTranslation: false)
    }
    .padding()
}