//
//  LiteRTGemmaModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Settings screen to manage the on-device Gemma (LiteRT) models. Each variant
//  (E2B, E4B) can be downloaded explicitly with progress instead of incurring a
//  silent multi-GB fetch on first use, shows its on-disk size, and can be
//  deleted to reclaim space.
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

    private(set) var status: [LiteRTGemmaVariant: Status] = [:]
    private(set) var sizeBytes: [LiteRTGemmaVariant: Int64] = [:]

    func status(for variant: LiteRTGemmaVariant) -> Status { status[variant] ?? .checking }

    func isBusy(_ variant: LiteRTGemmaVariant) -> Bool {
        switch status(for: variant) {
        case .downloading, .preparing: true
        default: false
        }
    }

    func refresh() async {
        for variant in LiteRTGemmaVariant.allCases {
            switch status[variant] {
            case .downloading, .preparing: continue // don't clobber an in-flight op
            default: break
            }
            let downloaded = await LiteRTModelManager.shared.isDownloaded(variant)
            sizeBytes[variant] = await LiteRTModelManager.shared.downloadedBytes(variant)
            status[variant] = downloaded ? .ready : .notDownloaded
        }
    }

    func prepare(_ variant: LiteRTGemmaVariant) async {
        status[variant] = .downloading(0)
        do {
            try await LiteRTModelManager.shared.ensureLoaded(variant: variant) { [weak self] fraction in
                Task { @MainActor in
                    guard let self else { return }
                    self.status[variant] = fraction >= 1.0 ? .preparing : .downloading(fraction)
                }
            }
            status[variant] = .ready
            sizeBytes[variant] = await LiteRTModelManager.shared.downloadedBytes(variant)
        } catch {
            status[variant] = .failed(error.localizedDescription)
        }
    }

    func delete(_ variant: LiteRTGemmaVariant) async {
        do {
            try await LiteRTModelManager.shared.deleteModel(variant)
            sizeBytes[variant] = 0
            status[variant] = .notDownloaded
        } catch {
            status[variant] = .failed(error.localizedDescription)
        }
    }
}

struct LiteRTGemmaModelView: View {
    @State private var model = LiteRTGemmaModelViewModel()

    var body: some View {
        Form {
            ForEach(LiteRTGemmaVariant.allCases, id: \.self) { variant in
                GemmaVariantSection(variant: variant, model: model)
            }
        }
        .navigationTitle("On-device Gemma")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refresh() }
    }
}

private struct GemmaVariantSection: View {
    let variant: LiteRTGemmaVariant
    let model: LiteRTGemmaModelViewModel

    var body: some View {
        Section {
            LabeledContent("Status") { statusLabel }

            if case .downloading(let fraction) = model.status(for: variant) {
                ProgressView(value: fraction)
            }

            let bytes = model.sizeBytes[variant] ?? 0
            if bytes > 0 {
                LabeledContent("On disk", value: bytes.formatted(.byteCount(style: .file)))
            }

            actionButton

            if case .failed(let message) = model.status(for: variant) {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(variant.displayName)
        } footer: {
            Text("\(variant.subtitle) Downloads \(variant.approxDownloadDescription) once. Private, offline, no API key.")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.status(for: variant) {
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

    @ViewBuilder
    private var actionButton: some View {
        switch model.status(for: variant) {
        case .ready:
            Button(role: .destructive) {
                Task { await model.delete(variant) }
            } label: {
                Label("Delete model", systemImage: "trash")
            }
            .disabled(model.isBusy(variant))
        case .notDownloaded, .failed:
            Button {
                Task { await model.prepare(variant) }
            } label: {
                Label("Download model (\(variant.approxDownloadDescription))", systemImage: "arrow.down.circle")
            }
            .disabled(model.isBusy(variant))
        case .checking, .downloading, .preparing:
            EmptyView()
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
