//
//  FullAccessPromptView.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2026.01.25
//

import SwiftUI

struct FullAccessPromptView: View {
    @Environment(\.openURL) private var openURL

    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Button {
                    HapticManager.lightImpact()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassDismissCircle(fallback: .quinary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer()

            // Content
            VStack(spacing: 16) {
                Text("Almost there!")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("To use voice transcription → allow **Full Access** in your Keyboard Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    HapticManager.mediumImpact()
                    openSettings()
                } label: {
                    Text("Finish setup")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.primary, in: .capsule)
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openSettings() {
        // Try to open the app's settings page which should show keyboard settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview {
    FullAccessPromptView(onDismiss: {})
}
