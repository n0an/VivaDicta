//
//  CoreMLQwenModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.27
//
//  Cards for the on-device Qwen3.5 models that run via CoreML on the Apple Neural
//  Engine (ANE), shown inline in the AI Providers "Local" tab. Parallel to the
//  MLX / LiteRT cards (same download/cancel/delete button + badges). Unlike those
//  GPU runtimes, CoreML works while the app is backgrounded, so these are the
//  on-device models that also run from the keyboard.
//

import SwiftUI
import Analytics
import DesignSystem
import LocalLLM

@MainActor
@Observable
final class CoreMLQwenModelViewModel {
    enum Status: Equatable {
        case checking
        case notDownloaded
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    private(set) var status: [CoreMLQwenVariant: Status] = [:]
    private(set) var sizeBytes: [CoreMLQwenVariant: Int64] = [:]

    private var tasks: [CoreMLQwenVariant: Task<Void, Never>] = [:]

    private let engine: any CoreMLQwenEngine

    init(engine: any CoreMLQwenEngine = CoreMLQwenModelManager.shared) {
        self.engine = engine
    }

    func status(for variant: CoreMLQwenVariant) -> Status { status[variant] ?? .checking }

    /// True while any model is downloading/preparing - used to lock other downloads.
    var isDownloading: Bool {
        status.values.contains {
            switch $0 { case .downloading, .preparing: true; default: false }
        }
    }

    func progress(for variant: CoreMLQwenVariant) -> Double {
        if case .downloading(let fraction) = status(for: variant) { return fraction }
        return 1
    }

    func refresh() async {
        for variant in CoreMLQwenVariant.allCases {
            switch status[variant] {
            case .downloading, .preparing: continue
            default: break
            }
            let downloaded = await engine.isDownloaded(variant)
            sizeBytes[variant] = await engine.downloadedBytes(variant)
            status[variant] = downloaded ? .ready : .notDownloaded
        }
    }

    @discardableResult
    func prepare(_ variant: CoreMLQwenVariant) -> Task<Void, Never> {
        tasks[variant]?.cancel()
        status[variant] = .downloading(0)
        let task = Task { @MainActor in
            let wasDownloaded = await engine.isDownloaded(variant)
            do {
                try await engine.ensureLoaded(variant: variant) { fraction in
                    Task { @MainActor in
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
                // already-downloaded model.
                if !wasDownloaded {
                    DefaultAnalyticsService.live.track(.modelDownloaded(name: variant.rawValue, type: "coreml"))
                }
            } catch is CancellationError {
                try? await engine.deleteModel(variant)
                self.status[variant] = .notDownloaded
            } catch {
                try? await engine.deleteModel(variant)
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

    func cancel(_ variant: CoreMLQwenVariant) {
        tasks[variant]?.cancel()
        tasks[variant] = nil
        status[variant] = .notDownloaded
    }

    func delete(_ variant: CoreMLQwenVariant) async {
        do {
            try await engine.deleteModel(variant)
            sizeBytes[variant] = 0
            status[variant] = .notDownloaded
        } catch {
            status[variant] = .failed(error.localizedDescription)
        }
    }
}

/// One card per on-device CoreML Qwen model, shown in the AI Providers "Local" tab.
struct CoreMLQwenModelCard: View {
    let variant: CoreMLQwenVariant
    let viewModel: CoreMLQwenModelViewModel
    /// When another model is downloading, this card's download action is locked.
    var downloadsLocked: Bool = false

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image("qwen-color")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                        Text(variant.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
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

            RuntimeBadge(runtime: "CoreML · Neural Engine")
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
                Task { await viewModel.delete(variant) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(variant.displayName)? You can download it again later.")
        }
    }

    private var sizeText: String {
        let bytes = viewModel.sizeBytes[variant] ?? 0
        return bytes > 0 ? bytes.formatted(.byteCount(style: .file)) : variant.approxDownloadDescription
    }

    private var status: CoreMLQwenModelViewModel.Status { viewModel.status(for: variant) }

    private var isDownloading: Bool {
        switch status {
        case .downloading, .preparing: true
        default: false
        }
    }

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
                Task { await viewModel.delete(variant) }
            case .downloading, .preparing:
                HapticManager.lightImpact()
                viewModel.cancel(variant)
            case .notDownloaded, .failed, .checking:
                HapticManager.lightImpact()
                viewModel.prepare(variant)
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
