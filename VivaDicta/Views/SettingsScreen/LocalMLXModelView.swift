//
//  LocalMLXModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.24
//
//  Cards for the on-device MLX models (GPU), shown inline in the AI Providers
//  "Local" tab. One generic card type over LocalMLXModel, parallel to the
//  LiteRT/Core ML cards (same download/cancel/delete button + badges).
//

import SwiftUI
import Analytics
import DesignSystem
import AICore

@MainActor
@Observable
final class LocalMLXModelViewModel {
    enum Status: Equatable {
        case checking
        case notDownloaded
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    private(set) var status: [LocalMLXModel: Status] = [:]
    private(set) var sizeBytes: [LocalMLXModel: Int64] = [:]

    private var tasks: [LocalMLXModel: Task<Void, Never>] = [:]

    private let engine: any LocalMLXModelEngine

    init(engine: any LocalMLXModelEngine = LocalMLXModelManager.shared) {
        self.engine = engine
    }

    func status(for model: LocalMLXModel) -> Status { status[model] ?? .checking }

    /// True while any model is downloading/preparing - used to lock other downloads.
    var isDownloading: Bool {
        status.values.contains {
            switch $0 { case .downloading, .preparing: true; default: false }
        }
    }

    func progress(for model: LocalMLXModel) -> Double {
        if case .downloading(let fraction) = status(for: model) { return fraction }
        return 1
    }

    func refresh() async {
        for model in LocalMLXModel.allCases {
            switch status[model] {
            case .downloading, .preparing: continue
            default: break
            }
            let downloaded = await engine.isDownloaded(model)
            sizeBytes[model] = await engine.downloadedBytes(model)
            status[model] = downloaded ? .ready : .notDownloaded
        }
    }

    @discardableResult
    func prepare(_ model: LocalMLXModel) -> Task<Void, Never> {
        tasks[model]?.cancel()
        status[model] = .downloading(0)
        let task = Task { @MainActor in
            let wasDownloaded = await engine.isDownloaded(model)
            do {
                // A Settings download loads into RAM, so keep memory single-resident.
                await OnDeviceModelMemory.shared.ensureOnlyResident(.mlx)
                try await engine.ensureLoaded(model: model) { fraction in
                    Task { @MainActor in
                        switch self.status[model] {
                        case .downloading, .preparing:
                            self.status[model] = fraction >= 1.0 ? .preparing : .downloading(fraction)
                        default:
                            break
                        }
                    }
                }
                self.status[model] = .ready
                self.sizeBytes[model] = await engine.downloadedBytes(model)
                // Track only a genuine new download, not a reload of an
                // already-downloaded model.
                if !wasDownloaded {
                    DefaultAnalyticsService.live.track(.modelDownloaded(name: model.rawValue, type: "mlx"))
                }
            } catch is CancellationError {
                // Discard the partial download so it can't later read as Ready.
                try? await engine.deleteModel(model)
                self.status[model] = .notDownloaded
            } catch {
                try? await engine.deleteModel(model)
                if (error as? URLError)?.code == .cancelled {
                    self.status[model] = .notDownloaded
                } else {
                    self.status[model] = .failed(error.localizedDescription)
                }
            }
            self.tasks[model] = nil
        }
        tasks[model] = task
        return task
    }

    func cancel(_ model: LocalMLXModel) {
        tasks[model]?.cancel()
        tasks[model] = nil
        status[model] = .notDownloaded
    }

    func delete(_ model: LocalMLXModel) async {
        do {
            try await engine.deleteModel(model)
            sizeBytes[model] = 0
            status[model] = .notDownloaded
        } catch {
            status[model] = .failed(error.localizedDescription)
        }
    }
}

/// One card per on-device MLX model, shown in the AI Providers "Local" tab.
struct MLXModelCard: View {
    let model: LocalMLXModel
    let viewModel: LocalMLXModelViewModel
    /// When another model is downloading, this card's download action is locked.
    var downloadsLocked: Bool = false

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        icon
                        Text(model.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    statusLabel
                    if model.isRecommendedForThisDevice {
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

            Text(model.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            RuntimeBadge(runtime: "MLX")
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
                Task { await viewModel.delete(model) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(model.displayName)? You can download it again later.")
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let asset = model.iconAsset {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        } else {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
        }
    }

    private var sizeText: String {
        let bytes = viewModel.sizeBytes[model] ?? 0
        return bytes > 0 ? bytes.formatted(.byteCount(style: .file)) : model.approxDownloadDescription
    }

    private var status: LocalMLXModelViewModel.Status { viewModel.status(for: model) }

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
                Task { await viewModel.delete(model) }
            case .downloading, .preparing:
                HapticManager.lightImpact()
                viewModel.cancel(model)
            case .notDownloaded, .failed, .checking:
                HapticManager.lightImpact()
                viewModel.prepare(model)
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
