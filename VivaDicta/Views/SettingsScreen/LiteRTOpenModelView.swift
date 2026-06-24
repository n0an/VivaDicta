//
//  LiteRTOpenModelView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.23
//
//  Cards for the on-device open LiteRT models (Llama / Ministral / Falcon /
//  DeepSeek), shown inline in the AI Providers "Local" tab below the Gemma and
//  Qwen cards. One generic card type over LiteRTOpenModel.
//

import SwiftUI
import DesignSystem
import LocalLLM

@MainActor
@Observable
final class LiteRTOpenModelViewModel {
    enum Status: Equatable {
        case checking
        case notDownloaded
        case downloading(Double)
        case preparing
        case ready
        case failed(String)
    }

    private(set) var status: [LiteRTOpenModel: Status] = [:]
    private(set) var sizeBytes: [LiteRTOpenModel: Int64] = [:]

    private var tasks: [LiteRTOpenModel: Task<Void, Never>] = [:]

    private let engine: any LiteRTOpenModelEngine

    init(engine: any LiteRTOpenModelEngine = LiteRTOpenModelManager.shared) {
        self.engine = engine
    }

    func status(for model: LiteRTOpenModel) -> Status { status[model] ?? .checking }

    /// True while any model is downloading/preparing - used to lock other downloads.
    var isDownloading: Bool {
        status.values.contains {
            switch $0 { case .downloading, .preparing: true; default: false }
        }
    }

    func progress(for model: LiteRTOpenModel) -> Double {
        if case .downloading(let fraction) = status(for: model) { return fraction }
        return 1
    }

    func refresh() async {
        for model in LiteRTOpenModel.allCases {
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
    func prepare(_ model: LiteRTOpenModel) -> Task<Void, Never> {
        tasks[model]?.cancel()
        status[model] = .downloading(0)
        let task = Task { @MainActor in
            do {
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
            } catch is CancellationError {
                self.status[model] = .notDownloaded
            } catch {
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

    func cancel(_ model: LiteRTOpenModel) {
        tasks[model]?.cancel()
        tasks[model] = nil
        status[model] = .notDownloaded
    }

    func delete(_ model: LiteRTOpenModel) async {
        do {
            try await engine.deleteModel(model)
            sizeBytes[model] = 0
            status[model] = .notDownloaded
        } catch {
            status[model] = .failed(error.localizedDescription)
        }
    }
}

/// One card per on-device open LiteRT model, shown in the AI Providers "Local"
/// tab below the Gemma and Qwen cards.
struct OpenModelCard: View {
    let model: LiteRTOpenModel
    let viewModel: LiteRTOpenModelViewModel
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

    private var status: LiteRTOpenModelViewModel.Status { viewModel.status(for: model) }

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
                Task { await viewModel.delete(model) }
            case .downloading, .preparing:
                HapticManager.lightImpact()
                viewModel.cancel(model)
            case .notDownloaded, .failed, .checking:
                HapticManager.lightImpact()
                viewModel.prepare(model)
            }
        } label: {
            if #available(iOS 26.0, *) {
                Image(systemName: symbolName, variableValue: isDownloading ? viewModel.progress(for: model) : 1)
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
                            .trim(from: 0, to: viewModel.progress(for: model))
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
        .disabled(downloadsLocked && isStartDownloadState)
    }
}
