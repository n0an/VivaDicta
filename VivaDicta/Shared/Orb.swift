//
//  Orb.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.24
//

import SwiftUI

struct OrbView: View {
    @State var isRotating = false
    
    var maskTimer: CGFloat = 0
    var blurEnabled = true
        
    var edgeLength: CGFloat = 100
    var delta: CGFloat = 30
    
    var body: some View {
        
        ZStack {
            AnimatedMeshGradient()
                .mask(
                    AnimatedRectangle(size: .init(width: edgeLength, height: edgeLength), cornerRadius: 20, t: CGFloat(maskTimer))
                        .frame(width: edgeLength, height: edgeLength)
                        .rotationEffect(.degrees(isRotating ? -360 : 0))
                        .animation(
                            .linear(duration: 10)
                            .repeatForever(autoreverses: false),
                            value: isRotating
                        )
                )
                .blur(radius: blurEnabled ? 20 : 0)
            
            AnimatedMeshGradient2()
                .mask(
                    AnimatedRectangle(size: .init(width: edgeLength - delta, height: edgeLength - delta), cornerRadius: 6, t: CGFloat(maskTimer))
                        .frame(width: edgeLength - delta, height: edgeLength - delta)
                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                        .rotation3DEffect(.degrees(isRotating ? 360 : 0), axis: (x: 1, y: 1, z: 1))
                        .animation(
                            .linear(duration: 5)
                            .repeatForever(autoreverses: false),
                            value: isRotating
                        )
                        .opacity(0.4)
                        
                )
            
                .blur(radius: blurEnabled ? 12 : 0)
        }
        .frame(width: edgeLength, height: edgeLength)
        .onAppear {
            isRotating = true
        }
        .onDisappear {
            isRotating = false
        }
    }
}

#Preview {
    
    @Previewable @State var maskTimer: CGFloat = 0
    @Previewable @State var timer: Timer?
    
    var edgeLength: CGFloat = 100
    var delta: CGFloat = 30
    
    OrbView(maskTimer: maskTimer)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                Task { @MainActor in
                    maskTimer += 0.1
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
}
