//
//  StrokeAnimatableShape.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.10
//

import SwiftUI

struct StrokeAnimatableShape<S: Shape>: Shape {
    var animationProgress: CGFloat = 0
    let shape: S

    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        return shape.path(in: rect)
            .trimmedPath(from: 0, to: animationProgress)
    }
}

struct StrokeAnimationShapeView<S: Shape>: View {
    @State private var animationProgress: CGFloat = 0
    let shape: S
    let lineColor: Color
    let lineWidth: CGFloat
    let duration: Double

    init(
        shape: S,
        lineColor: Color = .blue,
        lineWidth: CGFloat = 2,
        duration: Double = 1.0
    ) {
        self.shape = shape
        self.lineColor = lineColor
        self.lineWidth = lineWidth
        self.duration = duration
    }

    var body: some View {
        StrokeAnimatableShape(
            animationProgress: animationProgress,
            shape: shape
        )
        .stroke(lineColor, lineWidth: lineWidth)
        .onAppear {
            withAnimation(.linear(duration: duration)) {
                animationProgress = 1.0
            }
        }
    }
}

#Preview {
    StrokeAnimationShapeView(
        shape: RoundedRectangle(cornerRadius: 10),
        lineColor: .blue,
        lineWidth: 3,
        duration: 2.0
    )
    .frame(width: 200, height: 100)
    .padding()
}
