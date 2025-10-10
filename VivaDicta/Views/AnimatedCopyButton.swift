//
//  AnimatedCopyButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.14
//

import SwiftUI

struct AnimatedCopyButton: View {
    let textToCopy: String
    @State private var isCopied: Bool = false
    
    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: isCopied ? .bold : .regular))
                    .foregroundStyle(.white)
                Text(isCopied ? "Copied" : "Copy")
                    .font(.system(size: 12, weight: isCopied ? .medium : .regular))
                    .foregroundStyle(.white)
            }
        }
        .animatedCopyButtonStyle(color: .blue, colorPressed: .green.opacity(0.8), isPressed: isCopied)
        .scaleEffect(isCopied ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
    }
    
    private func copyToClipboard() {
        let _ = ClipboardManager.copyToClipboard(textToCopy)
        isCopied = true
        
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            isCopied = false
        }
    }
}

#Preview {
    AnimatedCopyButton(textToCopy: "")
}
