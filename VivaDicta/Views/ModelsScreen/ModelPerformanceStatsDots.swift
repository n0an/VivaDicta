//
//  ModelPerformanceStatsDots.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.03
//

import SwiftUI

struct ModelPerformanceStatsDots: View {
    var value: Double
    
    var body: some View {
        HStack(spacing: 8) {
            progressDots(value: value)
            Text(String(format: "%.1f", value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
    
    func progressDots(value: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 5) { index in
                Circle()
                    .fill(index < Int(value / 2) ? performanceColor(value: value / 10) : .gray)
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    func performanceColor(value: Double) -> Color {
        switch value {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}
