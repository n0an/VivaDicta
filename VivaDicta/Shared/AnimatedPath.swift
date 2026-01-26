//
//  AnimatedPath.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 24.11.2025.11.24
//

import SwiftUI

struct AnimatedRectangle: Shape {
    var size: CGSize
    var padding: Double = 8.0
    var cornerRadius: CGFloat
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = size.width
        let height = size.height
        let radius = cornerRadius

        // Define the initial points
        let initialPoints = [
            CGPoint(x: padding + radius, y: padding),
            CGPoint(x: width * 0.25 + padding, y: padding),
            CGPoint(x: width * 0.75 + padding, y: padding),
            CGPoint(x: width - padding - radius, y: padding),
            CGPoint(x: width - padding, y: padding + radius),
            CGPoint(x: width - padding, y: height * 0.25 - padding),
            CGPoint(x: width - padding, y: height * 0.75 - padding),
            CGPoint(x: width - padding, y: height - padding - radius),
            CGPoint(x: width - padding - radius, y: height - padding),
            CGPoint(x: width * 0.75 - padding, y: height - padding),
            CGPoint(x: width * 0.25 - padding, y: height - padding),
            CGPoint(x: padding + radius, y: height - padding),
            CGPoint(x: padding, y: height - padding - radius),
            CGPoint(x: padding, y: height * 0.75 - padding),
            CGPoint(x: padding, y: height * 0.25 - padding),
            CGPoint(x: padding, y: padding + radius)
        ]

        // Animate the points
        let points = initialPoints.map { point in
            CGPoint(
                x: point.x + 10 * sin(t + point.y * 0.1),
                y: point.y + 10 * sin(t + point.x * 0.1)
            )
        }

        // Draw the path
        path.move(to: CGPoint(x: padding, y: padding + radius))

        // Top edge
        for point in points[0...2] {
            path.addLine(to: point)
        }

        // Right edge
        for point in points[4...7] {
            path.addLine(to: point)
        }

        // Bottom edge
        for point in points[8...10] {
            path.addLine(to: point)
        }

        // Left edge
        for point in points[11...14] {
            path.addLine(to: point)
        }

        path.closeSubpath()

        return path
    }
}

#Preview("clipShape") {
    
    @Previewable @State var maskTimer: CGFloat = 0
    @Previewable @State var timer: Timer?
    
    AnimatedMeshGradient()
        .clipShape(AnimatedRectangle(size: .init(width: 100, height: 100), cornerRadius: 20, t: CGFloat(maskTimer)))
        .blur(radius: 28)
        .padding(40)
    
        .onAppear {
             timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                Task { @MainActor in
                    maskTimer += 0.1
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
}

#Preview("mask") {
    
    
    
    @Previewable @State var maskTimer: CGFloat = 0
    @Previewable @State var timer: Timer?
    
    @Previewable @State var isRotating = false
    
    var edgeLength: CGFloat = 100
    var delta: CGFloat = 30
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
                    .onAppear {
                        isRotating = true
                    }
            )
            .blur(radius: 20)

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
                    .onAppear {
                        isRotating = true
                    }
                    .opacity(0.4)
            )
            .blur(radius: 12)
    }
    .frame(width: edgeLength, height: edgeLength)


    
        .onAppear {
             timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                Task { @MainActor in
                    maskTimer += 0.1
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
}
