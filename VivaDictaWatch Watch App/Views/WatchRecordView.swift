//
//  WatchRecordView.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.02
//

import SwiftUI

struct WatchRecordView: View {
    let viewModel: WatchRecordViewModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            recordButton

            if viewModel.state == .recording {
                Text(formattedDuration)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            transferStatusView

            Spacer()
        }
    }

    private var recordButton: some View {
        Button(action: viewModel.toggleRecording) {
            Text(viewModel.state == .recording ? "Stop" : "Start")
                .font(.title3)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.state == .recording ? .red : .blue)
    }

    @ViewBuilder
    private var transferStatusView: some View {
        switch viewModel.transferStatus {
        case .idle:
            EmptyView()

        case .transferring(let count):
            Label("Uploading \(count) \(count == 1 ? "file" : "files")", systemImage: "icloud.and.arrow.up")
                .font(.caption2)
                .foregroundStyle(.secondary)

        case .allUploaded:
            Label("All uploaded", systemImage: "checkmark.icloud")
                .font(.caption2)
                .foregroundStyle(.green)

        case .error(let message):
            Label(message, systemImage: "exclamationmark.icloud")
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var formattedDuration: String {
        let minutes = Int(viewModel.recordingDuration) / 60
        let seconds = Int(viewModel.recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
