//
//  KeyboardFlowToast.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.03.06
//

import SwiftUI

struct KeyboardFlowToast: View {
    @Environment(AppState.self) var appState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            Text("Swipe back to continue\nVivaDicta dictation")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .glassEffectOrMaterial()
        .clipShape(.capsule)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .onAppear {
            HapticManager.mediumImpact()
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.showKeyboardFlowToast = false
                }
            }
        }
    }
}
