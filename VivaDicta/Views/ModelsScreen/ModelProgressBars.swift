//
//  ModelProgressBars.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.18
//

import SwiftUI

struct ModelProgressBars: View {
    let value: Int // 0-10 scale
    let color: Color

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<10) { index in
                Rectangle()
                    .fill(index < value ? color : Color.gray.opacity(0.2))
                    .frame(width: 12, height: 6)
                    .cornerRadius(1)
            }
        }
    }
}

struct ModelMetricRow: View {
    let label: String
    let value: Int // 0-10 scale
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            ModelProgressBars(value: value, color: color)

            Text("\(value)/10")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ModelMetricRow(label: "Speed", value: 9, color: .green)
        ModelMetricRow(label: "Accuracy", value: 6, color: .orange)
    }
    .padding()
}