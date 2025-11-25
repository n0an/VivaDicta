
import SwiftUI

struct HudView: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    var state: RecordingState
    
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
        case .transcribing:
            return "Transcribing"
        case .enhancing:
            return "Enhancing"
        default:
            return ""
        }
    }
    
    
    var body: some View {
        
        if colorScheme == .light {
            HudViewLight(statusIcon: statusIcon, statusText: statusText)
        } else {
            HudViewDark(statusIcon: statusIcon, statusText: statusText)
        }
    }
    
}



struct HudViewDark: View {
    
    var statusIcon: String
    var statusText: String
    
    @State var isSymbolAnimating = false
    
    
    @State var isShowing = true
    
    @State var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                
                if isShowing {
                    Image(systemName: statusIcon)
                        .transition(.asymmetric(insertion: .init(.symbolEffect(.drawOn)), removal: .opacity.combined(with: .scale)))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                        .font(.system(size: 50, weight: .semibold))
                        .onAppear { isSymbolAnimating = true }
                        .onDisappear { isSymbolAnimating = false }
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 50, weight: .semibold))
                        .opacity(0)
                }
                
            } else {
                Image(systemName: statusIcon)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                    .font(.system(size: 50, weight: .semibold))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }
            }
            
            
            Text(statusText)
                .font(.system(size: 17, weight: .semibold))
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    isShowing.toggle()
                }
            }
        }
        .animation(.default, value: isShowing)
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

struct HudViewLight: View {
    
    var statusIcon: String
    var statusText: String
    
    @State var isSymbolAnimating = false
    
    @State var isShowing = true
    
    @State var timer: Timer?
    
    var body: some View {
        
        VStack(spacing: 12) {
            if #available(iOS 26.0, *) {
                
                if isShowing {
                    Image(systemName: statusIcon)
                        .transition(.asymmetric(insertion: .init(.symbolEffect(.drawOn)), removal: .opacity.combined(with: .scale)))
                        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                        .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                        .font(.system(size: 50, weight: .semibold))
                        .onAppear { isSymbolAnimating = true }
                        .onDisappear { isSymbolAnimating = false }
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: 50, weight: .semibold))
                        .opacity(0)
                }
                
            } else {
                Image(systemName: statusIcon)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .symbolEffect(.bounce.up.byLayer, options: .repeat(.periodic(delay: 0.3)), isActive: isSymbolAnimating)
                    .font(.system(size: 50, weight: .semibold))
                    .onAppear { isSymbolAnimating = true }
                    .onDisappear { isSymbolAnimating = false }
            }
            
            Text(statusText)
                .font(.system(size: 17, weight: .semibold))
                .animation(.easeInOut(duration: 0.3), value: statusText)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    isShowing.toggle()
                }
            }
        }
        .animation(.default, value: isShowing)
        .foregroundColor(.white)
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 20)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 15)
    }
}

#Preview("Light") {
    VStack(spacing: 60) {
        HudView(state: .transcribing)
        HudView(state: .enhancing)
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: 60) {
        HudView(state: .transcribing)
        HudView(state: .enhancing)
    }
    .preferredColorScheme(.dark)
}
