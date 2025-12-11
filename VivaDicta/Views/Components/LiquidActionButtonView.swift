//
//  LiquidActionButtonView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.11
//

import SwiftUI

struct LiquidActionButtonView: View {
    @Binding var isExpanded: Bool
    let processingState: ProcessingState
    let canRetranscribe: Bool
    let canEnhance: Bool
    let onRetranscribeAndEnhance: () -> Void
    let onRetranscribe: () -> Void
    let onEnhance: () -> Void

    private let buttonSize: CGFloat = 56
    private let expandedOffset: CGFloat = 80
    private let diagonalOffset: CGFloat = 65

    var body: some View {
        ZStack {
            // Liquid canvas with material overlay
            Rectangle()
                .fill(isExpanded ? .ultraThinMaterial : .ultraThickMaterial)
                .overlay(Rectangle().fill(.black.opacity(0.5)).blendMode(.softLight))
                .mask(
                    liquidCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                )
                .shadow(color: .white.opacity(0.2), radius: 0, x: -1, y: -1)
                .shadow(color: .black.opacity(0.2), radius: 0, x: 1, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 5, y: 5)
                .overlay(
                    // Icons overlay - positioned relative to top-trailing
                    iconsOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                )
                .background(
                    decorativeCircles
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                )
                .contentShape(.rect)
                .onTapGesture {
                    guard processingState == .idle else { return }
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        isExpanded.toggle()
                    }
                }
        }
        .frame(width: 200, height: 200)
    }

    private var liquidCanvas: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.8, color: .green))
            context.addFilter(.blur(radius: 10))
            context.drawLayer { ctx in
                for index in 1...4 {
                    if let resolvedView = context.resolveSymbol(id: index) {
                        ctx.draw(resolvedView, at: CGPoint(x: size.width - buttonSize / 2, y: buttonSize / 2))
                    }
                }
            }
        } symbols: {
            // Main button circle
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .tag(1)

            // Retranscribe + Enhance (bottom)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(y: isExpanded ? expandedOffset : 0)
                .tag(2)

            // Retranscribe (left)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(x: isExpanded ? -expandedOffset : 0)
                .tag(3)

            // Enhance (diagonal bottom-left)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(x: isExpanded ? -diagonalOffset : 0, y: isExpanded ? diagonalOffset : 0)
                .tag(4)
        }
    }

    private var iconsOverlay: some View {
        // Icons positioned from top-right corner, matching canvas draw point
        ZStack(alignment: .topTrailing) {
            // Main button icon (arrow.clockwise when collapsed, xmark when expanded)
            Group {
                if processingState != .idle {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isExpanded ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .foregroundStyle(.green)
            .frame(width: buttonSize, height: buttonSize)

            // Retranscribe + Enhance button (bottom)
            Button(action: onRetranscribeAndEnhance) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.green)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!canRetranscribe)
            .opacity(isExpanded ? (canRetranscribe ? 1 : 0.4) : 0)
            .blur(radius: isExpanded ? 0 : 10)
            .scaleEffect(isExpanded ? 1 : 0.5)
            .offset(y: isExpanded ? expandedOffset : 0)

            // Retranscribe button (left)
            Button(action: onRetranscribe) {
                Image(systemName: "waveform")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!canRetranscribe)
            .opacity(isExpanded ? (canRetranscribe ? 1 : 0.4) : 0)
            .blur(radius: isExpanded ? 0 : 10)
            .scaleEffect(isExpanded ? 1 : 0.5)
            .offset(x: isExpanded ? -expandedOffset : 0)

            // Enhance button (diagonal bottom-left)
            Button(action: onEnhance) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.teal)
                    .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!canEnhance)
            .opacity(isExpanded ? (canEnhance ? 1 : 0.4) : 0)
            .blur(radius: isExpanded ? 0 : 10)
            .scaleEffect(isExpanded ? 1 : 0.5)
            .offset(x: isExpanded ? -diagonalOffset : 0, y: isExpanded ? diagonalOffset : 0)
        }
    }

    private var decorativeCircles: some View {
        ZStack {
            decorativeCircle.frame(width: 160)
            decorativeCircle.frame(width: 50)
            decorativeCircle.frame(width: 65)
        }
        .offset(x: buttonSize / 2 - 10, y: -buttonSize / 2 + 10)
        .scaleEffect(isExpanded ? 1 : 0.8, anchor: .topTrailing)
        .opacity(isExpanded ? 1 : 0)
        .animation(.easeOut(duration: 0.3), value: isExpanded)
    }

    private var decorativeCircle: some View {
        Circle()
            .stroke(lineWidth: 1)
            .fill(
                .linearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

#Preview("Collapsed") {
    LiquidActionButtonView(
        isExpanded: .constant(false),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Expanded") {
    LiquidActionButtonView(
        isExpanded: .constant(true),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}
