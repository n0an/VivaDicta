//
//  LiteRTGemmaModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Cards (one per on-device Gemma variant) shown inline in the AI Providers
//  "Local" tab, styled to match the Transcription Models cards - including the
//  same circular download/cancel/delete action button (progress is drawn inside
//  the button, no separate progress bar).
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

    /// In-flight download/load tasks, kept so the cancel button can stop them.
    private var tasks: [LiteRTGemmaVariant: Task<Void, Never>] = [:]

    func status(for variant: LiteRTGemmaVariant) -> Status { status[variant] ?? .checking }

    /// 0...1 progress for the action button; 1 when not actively downloading.
    func progress(for variant: LiteRTGemmaVariant) -> Double {
        if case .downloading(let fraction) = status(for: variant) { return fraction }
        return 1
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

    func prepare(_ variant: LiteRTGemmaVariant) {
        tasks[variant]?.cancel()
        status[variant] = .downloading(0)
        tasks[variant] = Task { @MainActor in
            do {
                try await LiteRTModelManager.shared.ensureLoaded(variant: variant) { fraction in
                    Task { @MainActor in
                        // Ignore late progress callbacks after a cancel/finish.
                        switch self.status[variant] {
                        case .downloading, .preparing:
                            self.status[variant] = fraction >= 1.0 ? .preparing : .downloading(fraction)
                        default:
                            break
                        }
                    }
                }
                self.status[variant] = .ready
                self.sizeBytes[variant] = await LiteRTModelManager.shared.downloadedBytes(variant)
            } catch is CancellationError {
                self.status[variant] = .notDownloaded
            } catch {
                if (error as? URLError)?.code == .cancelled {
                    self.status[variant] = .notDownloaded
                } else {
                    self.status[variant] = .failed(error.localizedDescription)
                }
            }
            self.tasks[variant] = nil
        }
    }

    func cancel(_ variant: LiteRTGemmaVariant) {
        tasks[variant]?.cancel()
        tasks[variant] = nil
        status[variant] = .notDownloaded
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
            HStack(alignment: .top, spacing: 10) {
                Image("gemma-color")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)

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
                        .lineLimit(1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6), in: .capsule)
                        .fixedSize(horizontal: true, vertical: false)

                    actionButton
                }
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

    private var status: LiteRTGemmaModelViewModel.Status { model.status(for: variant) }

    private var isDownloading: Bool {
        switch status {
        case .downloading, .preparing: true
        default: false
        }
    }

    private var symbolName: String {
        switch status {
        case .ready: "trash.circle"
        case .downloading, .preparing: "xmark.circle"
        case .notDownloaded, .failed, .checking: "arrow.down.circle.fill"
        }
    }

    private var symbolColor: Color {
        switch status {
        case .ready: .red
        case .downloading, .preparing: .primary
        case .notDownloaded, .failed, .checking: .blue
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch status {
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .downloading(let fraction):
            Text("Downloading \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .preparing:
            Text("Preparing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .notDownloaded, .checking:
            Text("Not downloaded")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .failed:
            Label("Failed - tap to retry", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }

    private var actionButton: some View {
        Button {
            switch status {
            case .ready:
                HapticManager.warning()
                Task { await model.delete(variant) }
            case .downloading, .preparing:
                HapticManager.lightImpact()
                model.cancel(variant)
            case .notDownloaded, .failed, .checking:
                HapticManager.lightImpact()
                model.prepare(variant)
            }
        } label: {
            if #available(iOS 26.0, *) {
                Image(systemName: symbolName, variableValue: isDownloading ? model.progress(for: variant) : 1)
                    .symbolVariableValueMode(.draw)
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(symbolColor)
                    .font(.system(size: 30))
            } else if isDownloading {
                Image(systemName: "xmark")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(symbolColor)
                    .font(.system(size: 16, weight: .bold))
                    .padding(8)
                    .background {
                        Circle()
                            .trim(from: 0, to: model.progress(for: variant))
                            .stroke(.primary, lineWidth: 3)
                            .rotationEffect(.degrees(-90))
                    }
            } else {
                Image(systemName: symbolName)
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(symbolColor)
                    .font(.system(size: 30))
            }
        }
        .buttonStyle(.plain)
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
