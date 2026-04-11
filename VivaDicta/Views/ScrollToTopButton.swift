//
//  ScrollToTopButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.23
//

import SwiftUI

struct ScrollToTopButton: View {
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button {
            HapticManager.lightImpact()
            action()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .scrollToTopBackground(color: backgroundColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Background Modifier

private struct ScrollToTopBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(color).interactive(true),
                    in: .circle
                )
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        } else {
            content
                .background(color)
                .clipShape(.circle)
                .shadow(color: .black.opacity(1), radius: 10, x: 0, y: 5)
        }
    }
}

extension View {
    fileprivate func scrollToTopBackground(color: Color) -> some View {
        modifier(ScrollToTopBackgroundModifier(color: color))
    }
}

#Preview {
    ScrollToTopButton(backgroundColor: .primary, action: {
        
    })
        .padding()
}
