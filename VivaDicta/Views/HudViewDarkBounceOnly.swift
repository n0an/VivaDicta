//
//  HudViewDarkBounceOnly.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.25
//

import SwiftUI

// MARK: - Not used. Keep for reference.
struct HudViewDarkBounceOnly: View {
    
    var statusIcon: String
    var statusText: String
    
    @State var isSymbolAnimating = false
    
    var body: some View {
        
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                .font(.system(size: 50, weight: .semibold))
                .onAppear { isSymbolAnimating = true }
                .onDisappear { isSymbolAnimating = false }
            
            Text(statusText)
                .font(.system(size: 17, weight: .semibold))
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .foregroundColor(.white)
        .padding()
        
        .background(
            AnimatedMeshGradient()
                .mask(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 20)
                        .blur(radius: 10)
                )
                .blendMode(.lighten)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(lineWidth: 3)
                .fill(Color.white)
                .blur(radius: 2)
                .blendMode(.overlay)
        )
        
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(lineWidth: 1)
                .fill(Color.white)
                .blur(radius: 1)
                .blendMode(.overlay)
        )
        .background(.black)
        .mask(RoundedRectangle(cornerRadius: 30, style: .continuous))
        
    }
}
