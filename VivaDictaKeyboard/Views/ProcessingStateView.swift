//
//  ProcessingStateView.swift
//  VivaDictaKeyboard
//
//  Created on 2025.10.03
//

import SwiftUI

// MARK: - Processing Stage Enum
public enum ProcessingStage {
    case waitingToStart
    case transcribing
    case enhancingWithAI
    case completed
    case error(String)
    
    var statusIcon: String {
        switch self {
        case .transcribing:
            "pencil.and.scribble"
        case .enhancingWithAI:
            "sparkles"
        default:
            ""
        }
    }

    var statusText: String {
        switch self {
        case .waitingToStart:
            return ""
        case .transcribing:
            return "Transcribing..."
        case .enhancingWithAI:
            return "Enhancing with AI..."
        case .completed:
            return "Completed"
        case .error(let message):
            return message
        }
    }
}

// MARK: - ProcessingStateView
struct ProcessingStateView: View {
    let processingStage: ProcessingStage
    let onCancel: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var isSymbolAnimating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top area with cancel button
            HStack {
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.horizontal, 8)
            }
            .padding(.bottom, 23)
            
            InfoView(processingStage: processingStage)
            .opacity(0)
            .overlay {
                AnimatedMeshGradient2()
                    .mask {
                        InfoView(processingStage: processingStage)
                    }
            }
            
        }
        .padding(.bottom, 71)
    }
    
}

struct InfoView: View {
    let processingStage: ProcessingStage
    @Environment(\.colorScheme) var colorScheme
    @State var isSymbolAnimating: Bool = false
    @State var isShowing = true
    @State var timer: Timer?
    var body: some View {
        
        VStack(spacing: 20) {
            
            if #available(iOS 26.0, *) {
                if isShowing {
                    Image(systemName: processingStage.statusIcon)
                        .transition(.asymmetric(insertion: .init(.symbolEffect(.drawOn)), removal: .opacity.combined(with: .scale(scale: 0.7))))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .foregroundStyle(.primary)
                        .font(.system(size: 50, weight: .semibold))
                } else {
                    Image(systemName: processingStage.statusIcon)
                        .font(.system(size: 50, weight: .semibold))
                        .opacity(0)
                }
                
            } else { // iOS 18 option
                
                Image(systemName: processingStage.statusIcon)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .foregroundStyle(Color.blue)
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                    .font(.system(size: 50, weight: .semibold))
            }
            
            // Processing status label
            Text(processingStage.statusText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .onAppear {
            isSymbolAnimating = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                        isShowing = false
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isShowing = true
                    }
                }
            }
        }
        .onDisappear {
            isSymbolAnimating = false
            
            timer?.invalidate()
            timer = nil
        }
    }
}
