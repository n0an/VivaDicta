//
//  AnimatedCopyButton.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.09.14
//

import SwiftUI

struct AnimatedCopyButton: View {
    let textToCopy: String
    var onCopy: (() -> Void)?
    @State private var isCopied: Bool = false

    var buttonHeight: CGFloat = 20
    
    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            
            if isCopied {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .frame(height: buttonHeight)
                    Text("Copied")
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .move(edge: .top))))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .frame(height: buttonHeight)
                    Text("Copy")
                }
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .move(edge: .top))))

            }
            
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .animatedCopyButtonStyle(color: .blue, colorPressed: .green.opacity(0.8), isPressed: isCopied)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
    }
    
    private func copyToClipboard() {
        let _ = ClipboardManager.copyToClipboard(textToCopy)
        HapticManager.mediumImpact()
        isCopied = true
        onCopy?()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            isCopied = false
        }
    }
}

#Preview {
    AnimatedCopyButton(textToCopy: "")
}
