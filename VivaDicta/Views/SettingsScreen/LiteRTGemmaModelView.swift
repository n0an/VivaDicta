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
import Analytics
import DesignSystem
import LocalLLM

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

    /// The model-lifecycle backend. Injected so tests can supply a mock; the
    /// app uses the shared `LiteRTModelManager`.
    private let engine: any LocalModelEngine

    init(engine: any LocalModelEngine = LiteRTModelManager.shared) {
        self.engine = engine
    }

    func status(for variant: LiteRTGemmaVariant) -> Status { status[variant] ?? .checking }

    /// True while any variant is downloading/preparing - used to lock other
    /// downloads (we run one model download at a time).
    var isDownloading: Bool {
        status.values.contains {
            switch $0 { case .downloading, .preparing: true; default: false }
        }
    }

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
            let downloaded = await engine.isDownloaded(variant)
            sizeBytes[variant] = await engine.downloadedBytes(variant)
            status[variant] = downloaded ? .ready : .notDownloaded
        }
    }

    /// Starts a download/load for `variant`. Returns the in-flight task so call
    /// sites (and tests) can await completion; the UI calls it fire-and-forget.
    @discardableResult
    func prepare(_ variant: LiteRTGemmaVariant) -> Task<Void, Never> {
        tasks[variant]?.cancel()
        status[variant] = .downloading(0)
        let task = Task { @MainActor in
            let wasDownloaded = await engine.isDownloaded(variant)
            do {
                try await engine.ensureLoaded(variant: variant) { fraction in
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
                self.sizeBytes[variant] = await engine.downloadedBytes(variant)
                // Track only a genuine new download, not a reload of an
                // already-downloaded variant.
                if !wasDownloaded {
                    DefaultAnalyticsService.live.track(.modelDownloaded(name: variant.rawValue, type: "litert"))
                }
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
        tasks[variant] = task
        return task
    }

    func cancel(_ variant: LiteRTGemmaVariant) {
        tasks[variant]?.cancel()
        tasks[variant] = nil
        status[variant] = .notDownloaded
    }

    func delete(_ variant: LiteRTGemmaVariant) async {
        do {
            try await engine.deleteModel(variant)
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
    /// When another model is downloading, this card's download action is locked.
    var downloadsLocked: Bool = false

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image("gemma-color")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        
                        Text(variant.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    statusLabel
                    if variant.isRecommendedForThisDevice {
                        RecommendedBadge()
                    }
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

            RuntimeBadge(runtime: "LiteRT")
        }
        .padding(20)
        .modelCardBackground()
        .contextMenu {
            if status == .ready {
                Button(role: .destructive) {
                    showDeleteAlert = true
                    HapticManager.warning()
                } label: {
                    Label("Delete Model", systemImage: "trash")
                }
            }
        }
        .alert("Delete Model", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await model.delete(variant) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(variant.displayName)? You can download it again later.")
        }
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

    /// True when tapping the button would START a download (so it should be
    /// disabled while another model is downloading).
    private var isStartDownloadState: Bool {
        switch status {
        case .notDownloaded, .failed, .checking: true
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
        case .downloading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Downloading...")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        case .preparing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Preparing...")
            }
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
            // Indeterminate while downloading: the symbol is the cancel "x" (see
            // symbolName); no progress ring because multi-file model progress is
            // non-linear and reads as stuck.
            Image(systemName: symbolName)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(symbolColor)
                .font(.system(size: 30))
        }
        .buttonStyle(.plain)
        .disabled(downloadsLocked && isStartDownloadState)
    }
}

/// Small subtle tag naming the on-device runtime that powers a model card
/// ("LiteRT" / "Core ML").
struct RuntimeBadge: View {
    let runtime: String

    var body: some View {
        Label(runtime, systemImage: "cpu")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.secondary.opacity(0.12), in: .capsule)
    }
}

/// Small blue "Recommended" pill, matching the Transcription Models cards.
struct RecommendedBadge: View {
    var body: some View {
        Text("Recommended")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.blue.opacity(0.15), in: .rect(cornerRadius: 12))
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
