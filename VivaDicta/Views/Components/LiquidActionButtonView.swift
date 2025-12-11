//
//  LiquidActionButtonView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.11
//

import SwiftUI

enum LiquidButtonExpandDirection {
    case up
    case down
}

struct LiquidActionButtonView: View {
    @Binding var isExpanded: Bool
    let processingState: ProcessingState
    let canRetranscribe: Bool
    let canEnhance: Bool
    let expandDirection: LiquidButtonExpandDirection
    let onRetranscribeAndEnhance: () -> Void
    let onRetranscribe: () -> Void
    let onEnhance: () -> Void

    private let buttonSize: CGFloat = 56
    private let expandedOffset: CGFloat = 80
    private let diagonalOffset: CGFloat = 65

    /// Height needed when expanded: main button center + offset + half button + label space
    private var expandedHeight: CGFloat {
        buttonSize / 2 + expandedOffset + buttonSize / 2 + labelSpace
    }

    /// Extra space for labels below buttons
    private let labelSpace: CGFloat = 30

    /// Width needed: main button center + offset + half button for the left button
    private var expandedWidth: CGFloat {
        buttonSize / 2 + expandedOffset + buttonSize / 2
    }

    private var frameHeight: CGFloat {
        isExpanded ? expandedHeight : buttonSize
    }

    private var frameWidth: CGFloat {
        isExpanded ? expandedWidth : buttonSize
    }

    /// Multiplier for vertical offsets: +1 for down, -1 for up
    private var verticalDirection: CGFloat {
        expandDirection == .down ? 1 : -1
    }

    /// Alignment for the main container based on expand direction
    private var containerAlignment: Alignment {
        expandDirection == .down ? .topTrailing : .bottomTrailing
    }

    /// Y position for drawing circles in canvas
    private var canvasDrawY: CGFloat {
        expandDirection == .down ? buttonSize / 2 : frameHeight - buttonSize / 2
    }

    var body: some View {
        ZStack(alignment: containerAlignment) {
            // Liquid canvas with material overlay
            Rectangle()
                .fill(isExpanded ? .ultraThinMaterial : .ultraThickMaterial)
                .overlay(Rectangle().fill(.black.opacity(0.5)).blendMode(.softLight))
                .mask(liquidCanvas)
                .shadow(color: .white.opacity(0.2), radius: 0, x: -1, y: -1)
                .shadow(color: .black.opacity(0.2), radius: 0, x: 1, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 5, y: 5)
                .overlay(alignment: containerAlignment) {
                    iconsOverlay
                }
                .background(alignment: containerAlignment) {
                    decorativeCircles
                }
                .contentShape(.rect)
                .onTapGesture {
                    guard processingState == .idle else { return }
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                        isExpanded.toggle()
                    }
                }
        }
        .frame(width: frameWidth, height: frameHeight, alignment: containerAlignment)
    }

    private var liquidCanvas: some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.8, color: .green))
            context.addFilter(.blur(radius: 10))
            context.drawLayer { ctx in
                for index in 1...4 {
                    if let resolvedView = context.resolveSymbol(id: index) {
                        ctx.draw(resolvedView, at: CGPoint(x: size.width - buttonSize / 2, y: canvasDrawY))
                    }
                }
            }
        } symbols: {
            // Main button circle
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .tag(1)

            // Retranscribe + Enhance (vertical)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(y: isExpanded ? expandedOffset * verticalDirection : 0)
                .tag(2)

            // Retranscribe (left)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(x: isExpanded ? -expandedOffset : 0)
                .tag(3)

            // Enhance (diagonal)
            Circle()
                .fill(.black)
                .frame(width: buttonSize, height: buttonSize)
                .offset(x: isExpanded ? -diagonalOffset : 0, y: isExpanded ? diagonalOffset * verticalDirection : 0)
                .tag(4)
        }
        .frame(width: frameWidth, height: frameHeight)
    }

    private var iconsOverlay: some View {
        ZStack(alignment: containerAlignment) {
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

            // Retranscribe + Enhance button (vertical)
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
            .offset(y: isExpanded ? expandedOffset * verticalDirection : 0)

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

            // Enhance button (diagonal)
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
            .offset(x: isExpanded ? -diagonalOffset : 0, y: isExpanded ? diagonalOffset * verticalDirection : 0)

            // Text labels (only visible when expanded)
            labelsOverlay
        }
    }

    private var labelsOverlay: some View {
        let labelOffset: CGFloat = buttonSize / 2 + 24  // Below/above button

        return ZStack(alignment: containerAlignment) {
            // Label for Retranscribe + Enhance (vertical button)
            Text("Transcribe\n+ Enhance")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize()
                .offset(
                    y: isExpanded
                        ? (expandedOffset + labelOffset) * verticalDirection
                        : 0
                )

            // Label for Retranscribe (left button)
            Text("Transcribe")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .offset(
                    x: isExpanded ? -expandedOffset : 0,
                    y: isExpanded ? labelOffset * verticalDirection : 0
                )

            // Label for Enhance (diagonal button)
            Text("Enhance")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .offset(
                    x: isExpanded ? -diagonalOffset : 0,
                    y: isExpanded ? (diagonalOffset + labelOffset) * verticalDirection : 0
                )
        }
        .opacity(isExpanded ? 1 : 0)
        .blur(radius: isExpanded ? 0 : 10)
        .scaleEffect(isExpanded ? 1 : 0.5)
    }

    private var decorativeCircles: some View {
        let yOffset = expandDirection == .down ? -buttonSize / 2 + 10 : buttonSize / 2 - 10
        let scaleAnchor: UnitPoint = expandDirection == .down ? .topTrailing : .bottomTrailing

        return ZStack {
            decorativeCircle.frame(width: 120)
            decorativeCircle.frame(width: 40)
            decorativeCircle.frame(width: 55)
        }
        .offset(x: buttonSize / 2 - 10, y: yOffset)
        .scaleEffect(isExpanded ? 1 : 0.8, anchor: scaleAnchor)
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

#Preview("Collapsed - Down") {
    LiquidActionButtonView(
        isExpanded: .constant(false),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        expandDirection: .down,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Expanded - Down") {
    LiquidActionButtonView(
        isExpanded: .constant(true),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        expandDirection: .down,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Collapsed - Up") {
    LiquidActionButtonView(
        isExpanded: .constant(false),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        expandDirection: .up,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Expanded - Up") {
    LiquidActionButtonView(
        isExpanded: .constant(true),
        processingState: .idle,
        canRetranscribe: true,
        canEnhance: true,
        expandDirection: .up,
        onRetranscribeAndEnhance: {},
        onRetranscribe: {},
        onEnhance: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    .padding()
    .background(Color.gray.opacity(0.3))
}
