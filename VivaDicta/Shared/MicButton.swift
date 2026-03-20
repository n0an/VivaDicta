//
//  MicButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.12.05
//

import SwiftUI

struct MicButton: View {
    @State var isAnimating = false
    
    var fontSize: CGFloat
    var padding: CGFloat
    var backgroundColor: Color
    var borderWidth: CGFloat
    
    var onTapAction: () -> Void
    
    
    var body: some View {
        
        
        Button {
            onTapAction()
        } label: {
            
            Image(systemName: "microphone.circle")
                .foregroundColor(.primary)
                .font(.system(size: fontSize))
                .padding(padding)
                .background(backgroundColor.gradient, in: .circle)
                
                .background {
                    Circle()
                    
                        .fill(AngularGradient(colors: [.teal, .pink, .teal], center: .center, angle: .degrees(isAnimating ? 360 : 0)))
                        .blur(radius: 10)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 7).repeatForever(autoreverses: false)) {
                                isAnimating = true
                            }
                        }
                        .onDisappear {
                            isAnimating = false
                        }
                }
            
                .overlay {
                    Circle()
                        .stroke(.black.opacity(0.5), lineWidth: borderWidth)
                }
        }
        
        
        
    }
}


#Preview {
    MicButton(
        fontSize: 34,
        padding: 6,
        backgroundColor: .orange.opacity(0.5),
        borderWidth: 0.5,
        onTapAction: {})
}
