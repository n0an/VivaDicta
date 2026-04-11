//
//  TypingIndicator.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.10
//

import SwiftUI

/// Animated indicator showing the AI is generating a response.
struct TypingIndicator: View {
    @State private var animatingDots = false

    var body: some View {
        HStack {
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor, isActive: animatingDots)
                .font(.title)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .clipShape(.rect(cornerRadius: 16))

            Spacer(minLength: 60)
        }
        .padding(.horizontal)
        .onAppear {
            animatingDots = true
        }
    }
}
