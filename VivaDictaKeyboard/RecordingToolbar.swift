//
//  RecordingToolbar.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.09.30
//

import SwiftUI

struct RecordingToolbar: View {
    let onRecordTapped: () -> Void

    var body: some View {
        HStack {
            // Left spacer
            Spacer()

            // Record button
            Button(action: onRecordTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.blue)

                    Text("Record")
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

            // Right spacer
            Spacer()
        }
        .padding(.horizontal)
    }
}


