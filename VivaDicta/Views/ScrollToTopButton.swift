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
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(.systemBackground))
                .frame(width: 44, height: 44)
                .background(backgroundColor)
                .clipShape(.circle)
                .shadow(color: .black.opacity(1), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
//        .tint(.primary)
    }
}

#Preview {
    ScrollToTopButton(backgroundColor: .primary, action: {
        
    })
        .padding()
}
