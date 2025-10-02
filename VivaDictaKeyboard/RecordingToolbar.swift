//
//  RecordingToolbar.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import SwiftUI

struct RecordingToolbar: View {
    let isMainAppActive: Bool
    let onRecordTapped: () -> Void

    private var buttonColor: Color {
        isMainAppActive ? Color.green : Color.gray
    }

    private var buttonText: String {
        isMainAppActive ? "Record" : "Open App"
    }

    private var buttonIcon: String {
        isMainAppActive ? "mic.circle.fill" : "arrow.up.forward.app.fill"
    }

    var body: some View {
        HStack {
            // Left spacer
            Spacer()

            // Record button
            Button(action: onRecordTapped) {
                HStack(spacing: 8) {
                    Image(systemName: buttonIcon)
                        .font(.system(size: 24))
                        .foregroundStyle(buttonColor)

                    Text(buttonText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(buttonColor.opacity(0.3), lineWidth: 1)
                )
            }
            .animation(.easeInOut(duration: 0.2), value: isMainAppActive)

            // Right spacer
            Spacer()
        }
        .padding(.horizontal)
    }
}


