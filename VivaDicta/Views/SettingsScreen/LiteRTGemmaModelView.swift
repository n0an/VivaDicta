//
//  LiteRTGemmaModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Settings screen to manage the on-device Gemma (LiteRT) models, shown as
//  standalone cards (one per variant) in the style of the Transcription Models
//  screen. Each card downloads its variant explicitly with progress, shows its
//  on-disk size, and can delete it to reclaim space.
//

import SwiftUI
import DesignSystem

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

/// One card per on-device Gemma variant (E2B/E4B), shown inline in the AI
/// Providers "Local" tab. Styled like the Transcription Models cards.
struct GemmaVariantCard: View {
    let variant: LiteRTGemmaVariant
    let model: LiteRTGemmaModelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(variant.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    statusLabel
                }

                Spacer()

                HStack(spacing: 8) {
                    Label(sizeText, systemImage: "internaldrive")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6), in: .capsule)

                    actionButton
                }
            }

            if case .downloading(let fraction) = model.status(for: variant) {
                ProgressView(value: fraction)
            }

            Text(variant.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .modelCardBackground()
    }

    private var sizeText: String {
        let bytes = model.sizeBytes[variant] ?? 0
        return bytes > 0 ? bytes.formatted(.byteCount(style: .file)) : variant.approxDownloadDescription
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch model.status(for: variant) {
        case .checking:
            Text("Checking...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .notDownloaded:
            Text("Not downloaded")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .downloading(let fraction):
            Text("Downloading \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .preparing:
            Text("Preparing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .failed:
            Label("Failed - tap to retry", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch model.status(for: variant) {
        case .ready:
            Button {
                HapticManager.warning()
                Task { await model.delete(variant) }
            } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.red)
            }
        case .checking, .downloading, .preparing:
            ProgressView()
                .frame(width: 30, height: 30)
        case .notDownloaded, .failed:
            Button {
                HapticManager.lightImpact()
                Task { await model.prepare(variant) }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        GemmaVariantCard(variant: .e2b, model: LiteRTGemmaModelViewModel())
        GemmaVariantCard(variant: .e4b, model: LiteRTGemmaModelViewModel())
    }
    .padding()
}
#endif
