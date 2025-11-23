//
//  HudView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.23
//

import SwiftUI

enum HudState {
    case transcribing
    case enhancing
}

struct HudView: View {
    
    
    var state: HudState
    
    var statusIcon: String {
        switch state {
        case .transcribing:
            return "pencil.and.scribble"
        case .enhancing:
            return "sparkles"
        }
    }
    
    var statusText: String {
        switch state {
        case .transcribing:
            return "Transcribing"
        case .enhancing:
            return "Enhancing"
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
        .padding()
        .background(.gray.opacity(0.2), in: .rect(cornerRadius: 20))
    }
}


#Preview {
    HudView(state: .transcribing)
    HudView(state: .enhancing)
}
