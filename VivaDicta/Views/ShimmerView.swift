//
//  ShimmerView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.09
//

import SwiftUI

struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(0.4),
                    .white.opacity(0.6),
                    .white.opacity(0.4),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.6)
            .offset(x: shimmerOffset * geometry.size.width)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5)) {
                    shimmerOffset = 1.4
                }
            }
        }
        .clipped()
    }
}

#Preview {
    VStack {
        Text("This is some sample text that will have a shimmer effect applied to it when the copy button is pressed.")
            .padding()
            .overlay {
                ShimmerView()
            }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
