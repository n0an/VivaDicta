//
//  HudView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.23
//

import SwiftUI

struct HudView: View {
    
    var state: RecordingState = .transcribing
    
    var statusIcon: String {
        switch state {
        case .transcribing:
            return "pencil.and.scribble"
        case .enhancing:
            return "sparkles"
        default:
            return "microphone.circle.fill"
        }
    }
    
    var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .enhancing:
            return "Enhancing"
        default:
            return ""
        }
    }
    
    @State var isSymbolAnimating = false
    
    
    
    var body: some View {
        
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(Color.blue)
                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                .font(.system(size: 50, weight: .semibold))
//                .frame(height: 50)
                .onAppear { isSymbolAnimating = true }
                .onDisappear { isSymbolAnimating = false }
            
            // Processing status label
            Text(statusText)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        
    }
}


#Preview {
    HudView(state: .transcribing)
}
