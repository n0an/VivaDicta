//
//  HudViewLightBounceOnly.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.25
//

import SwiftUI

// MARK: - Not used. Keep for reference.
struct HudViewLightBounceOnly: View {
    
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
        .foregroundStyle(.white)
        .padding()
        
        .background(
            ZStack {
                AnimatedMeshGradient()
                    .mask(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(lineWidth: 16)
                            .blur(radius: 8)
                    )

                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 3)
                            .fill(Color.white)
                            .blur(radius: 2)
                            .blendMode(.overlay)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(lineWidth: 1)
                            .fill(Color.white)
                            .blur(radius: 1)
                            .blendMode(.overlay)
                    )
            }
        )
        .background(
            ZStack {
                AnimatedMeshGradient()
                    .frame(width: 400, height: 800)
                    .opacity(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        )
        .background(.black)
        .clipShape(.rect(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 20)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 15)
    }
}

