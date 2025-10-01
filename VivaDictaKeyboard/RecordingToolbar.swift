//
//  RecordingToolbar.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import SwiftUI

struct RecordingToolbar: View {
    @Binding var isRecording: Bool
    let onRecordTapped: () -> Void

    var body: some View {
        HStack {
            // Left spacer
            Spacer()

            // Record button
            Button(action: onRecordTapped) {
                HStack(spacing: 8) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isRecording ? Color.red : Color.blue)

                    Text(isRecording ? "Recording..." : "Record")
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
            }
            .disabled(isRecording)

            // Right spacer
            Spacer()
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }
}

// MARK: - Preview

struct RecordingToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RecordingToolbar(isRecording: .constant(false)) {
                // Preview action
            }
            .frame(height: 44)
            .background(Color(UIColor.systemGray6))

            RecordingToolbar(isRecording: .constant(true)) {
                // Preview action
            }
            .frame(height: 44)
            .background(Color(UIColor.systemGray6))
        }
    }
}