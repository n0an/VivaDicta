
import SwiftUI

struct HudView: View {
    
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
    
    @State var isSymbolAnimating = false
    
    var body: some View {
        
        VStack(spacing: 12) {
            Image(systemName: statusIcon)
                .contentTransition(.symbolEffect(.replace))
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


#Preview {
    VStack(spacing: 60) {
        HudView(state: .transcribing)
        HudView(state: .enhancing)
    }
}
