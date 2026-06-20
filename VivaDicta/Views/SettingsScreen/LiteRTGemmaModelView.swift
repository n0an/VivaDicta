//
//  LiteRTGemmaModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Settings screen to manage the on-device Gemma (LiteRT) model: download it
//  explicitly (with progress) instead of incurring a silent ~2.6 GB fetch on
//  first use, see its on-disk size, and delete it to reclaim space.
//

import SwiftUI

@MainActor
@Observable
final class LiteRTGemmaModelViewModel {
    enum Status: Equatable {
        case checking
        case notDownloaded
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    private(set) var status: Status = .checking
    private(set) var onDiskBytes: Int64 = 0

    var isBusy: Bool {
        switch status {
        case .downloading, .preparing: true
        default: false
        }
    }

    func refresh() async {
        let downloaded = await LiteRTModelManager.shared.isDownloaded
        onDiskBytes = await LiteRTModelManager.shared.downloadedBytes
        if case .downloading = status { return } // don't clobber an in-flight download
        if case .preparing = status { return }
        status = downloaded ? .ready : .notDownloaded
    }

    func prepare() async {
        status = .downloading(0)
        do {
            try await LiteRTModelManager.shared.ensureLoaded { [weak self] fraction in
                Task { @MainActor in
                    guard let self else { return }
                    self.status = fraction >= 1.0 ? .preparing : .downloading(fraction)
                }
            }
            status = .ready
            onDiskBytes = await LiteRTModelManager.shared.downloadedBytes
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func delete() async {
        do {
            try await LiteRTModelManager.shared.deleteModel()
            onDiskBytes = 0
            status = .notDownloaded
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}

struct LiteRTGemmaModelView: View {
    @State private var model = LiteRTGemmaModelViewModel()

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    statusLabel
                }
                if case .downloading(let fraction) = model.status {
                    ProgressView(value: fraction)
                }
                if model.onDiskBytes > 0 {
                    LabeledContent("On disk", value: model.onDiskBytes.formatted(.byteCount(style: .file)))
                }
            } header: {
                Text("On-device Gemma")
            } footer: {
                Text("Gemma 4 (E2B) runs fully on your device via LiteRT - private, offline, no API key. The model is about 2.6 GB and downloads once. Use Wi-Fi, and keep the app open while it downloads.")
            }

            Section {
                switch model.status {
                case .ready:
                    Button(role: .destructive) {
                        Task { await model.delete() }
                    } label: {
                        Label("Delete model", systemImage: "trash")
                    }
                    .disabled(model.isBusy)
                case .notDownloaded, .failed:
                    Button {
                        Task { await model.prepare() }
                    } label: {
                        Label("Download model (~2.6 GB)", systemImage: "arrow.down.circle")
                    }
                    .disabled(model.isBusy)
                case .checking, .downloading, .preparing:
                    EmptyView()
                }
            }

            if case .failed(let message) = model.status {
                Section {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("On-device Gemma")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.status {
        case .checking:
            Text("Checking...").foregroundStyle(.secondary)
        case .notDownloaded:
            Text("Not downloaded").foregroundStyle(.secondary)
        case .downloading(let fraction):
            Text("Downloading \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                .foregroundStyle(.secondary)
        case .preparing:
            Text("Preparing...").foregroundStyle(.secondary)
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LiteRTGemmaModelView()
    }
}
#endif
