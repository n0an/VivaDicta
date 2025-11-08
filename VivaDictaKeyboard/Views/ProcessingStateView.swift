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
            return "Processing..."
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
    
    @State var isSymbolAnimating: Bool = false

    // Get the keyboard appearance from environment
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Top area with cancel button
            HStack {
                Spacer()
                
                // Cancel button (X)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.gray.opacity(0.1), in: .circle)
                        .contentShape(.rect)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Center area with icon and status label
            VStack(spacing: 20) {
                Image(systemName: processingStage.statusIcon)
                    .foregroundStyle(Color.blue)
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                    .font(.system(size: 30))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }
                    .padding(.vertical, 20)
                
                // Processing status label
                Text(processingStage.statusText)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.3), value: processingStage.statusText)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Bottom padding to match keyboard height
            Rectangle()
                .fill(Color.clear)
                .frame(height: 100)
        }
    }
}
