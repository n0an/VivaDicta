//
//  Orb.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.24
//

import SwiftUI
import SiriWaveView
import Charts

struct OrbView: View {
    @State var isRotating = false
    
    var maskTimer: CGFloat = 0
    var blurEnabled = true
        
    var edgeLength: CGFloat = 100
    var delta: CGFloat = 30
    
    var body: some View {
        
        ZStack {
            AnimatedMeshGradient()
                .mask(
                    AnimatedRectangle(size: .init(width: edgeLength, height: edgeLength), cornerRadius: 20, t: CGFloat(maskTimer))
                        .frame(width: edgeLength, height: edgeLength)
                        .rotationEffect(.degrees(isRotating ? -360 : 0))
                        .animation(
                            .linear(duration: 10)
                            .repeatForever(autoreverses: false),
                            value: isRotating
                        )
                )
                .blur(radius: blurEnabled ? 20 : 0)
            
            AnimatedMeshGradient2()
                .mask(
                    AnimatedRectangle(size: .init(width: edgeLength - delta, height: edgeLength - delta), cornerRadius: 6, t: CGFloat(maskTimer))
                        .frame(width: edgeLength - delta, height: edgeLength - delta)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                        .rotation3DEffect(.degrees(isRotating ? 360 : 0), axis: (x: 1, y: 1, z: 1))
                        .animation(
                            .linear(duration: 5)
                            .repeatForever(autoreverses: false),
                            value: isRotating
                        )
                        .opacity(0.4)
                        
                )
            
                .blur(radius: blurEnabled ? 12 : 0)
        }
        .frame(width: edgeLength, height: edgeLength)
        .onAppear {
            isRotating = true
        }
        .onDisappear {
            isRotating = false
        }
    }
}

#Preview {
    
    
    
    @Previewable @State var maskTimer: CGFloat = 0
    @Previewable @State var timer: Timer?
    
    @Previewable @State var currentAudioLevel = 0.0
    
    var rectangleSpeed: CGFloat {
        
        
        
        // Logarithmic scaling: fast growth initially, then slower
        // Using log(1 + x*k) / log(1 + k) to map [0,1] to [0,1] logarithmically
        let k: CGFloat = 4.0 // Controls the curve shape (higher = steeper initial growth)
        let normalizedLevel = min(max(currentAudioLevel, 0), 1) // Ensure 0-1 range
        let logarithmicLevel = log(1 + normalizedLevel * k) / log(1 + k)
        return logarithmicLevel * 0.2 // Scale to appropriate speed range
        

    }
    
    var edgeLength: CGFloat = 100
    var delta: CGFloat = 30
    
    var tick = 1
    
    VStack {
        Text("\(currentAudioLevel)")
            .foregroundStyle(.red)
        SiriWaveView(power: .constant(currentAudioLevel))
            .frame(height: 140)
    }
    .padding()
    .border(.red, width: 1)
    
    VStack {
        Text("\(rectangleSpeed)")
            .foregroundStyle(.blue)
        OrbView(maskTimer: maskTimer)
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                    Task { @MainActor in
                        tick += 1
                        if tick % 60 == 0 {
                            currentAudioLevel += 0.05
                            
                            if currentAudioLevel > 1 {
                                currentAudioLevel = 0
                            }
                        }
                        
                        maskTimer += rectangleSpeed
                        
                        
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

}


struct ChartDataPoint: Identifiable {
    let id = UUID()
    let audioLevel: Double
    let logarithmicSpeed: Double
    let linearSpeed: Double
}

#Preview("chart") {
    // Generate data points for the chart
    let dataPoints: [ChartDataPoint] = (0...100).map { i in
        let level = Double(i) / 100.0

        // Logarithmic scaling
        let k: Double = 4.0
        let normalizedLevel = min(max(level, 0), 1)
        let logarithmicLevel = log(1 + normalizedLevel * k) / log(1 + k)
        let logSpeed = logarithmicLevel * 0.2

        // Linear scaling for comparison
        let linSpeed = normalizedLevel

        return ChartDataPoint(
            audioLevel: level,
            logarithmicSpeed: logSpeed,
            linearSpeed: linSpeed
        )
    }

    VStack {
        Text("Audio Level to Animation Speed Mapping")
            .font(.headline)
            .padding(.bottom)

        Chart(dataPoints) { point in
            // Logarithmic curve
            BarMark(
                x: .value("Audio Level", point.audioLevel),
                y: .value("Speed", point.logarithmicSpeed)
            )
            .foregroundStyle(Color.blue)
            .symbolSize(0)

            // Linear curve for comparison
            LineMark(
                x: .value("Audio Level", point.audioLevel),
                y: .value("Speed", point.linearSpeed)
            )
            .foregroundStyle(Color.red.opacity(0.7))
            .symbolSize(0)
        }
        .frame(height: 350)
        .padding()
        .chartXAxisLabel("Audio Level (0 to 1)")
        .chartYAxisLabel("Animation Speed")
        .chartXScale(domain: 0...1)
        .chartYScale(domain: 0...1)
        .chartLegend(position: .top) {
            HStack(spacing: 20) {
                Label("Logarithmic (k=9.0)", systemImage: "circle.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Label("Linear (old)", systemImage: "circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
                    .font(.caption)
            }
        }

        // Show the difference
        Text("The logarithmic curve rises quickly for quiet sounds (0.0-0.3),\nthen levels off for louder sounds (0.7-1.0)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top)
    }
    .padding()
}
