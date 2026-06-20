//
//  LiteRTSpikeView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Phase 0 spike screen (DEBUG only). Downloads Gemma 4 E2B via LiteRT-LM,
//  runs a real preset prompt, and reports load time, first-token latency,
//  throughput, and peak memory footprint. Physical device only - the iOS
//  Simulator has no Metal GPU path and falls back to slow CPU.
//
//  See llmtemp/litert-gemma-integration-plan.md.
//

import SwiftUI

struct LiteRTSpikeView: View {
    @State private var model = LiteRTSpikeModel()

    private var presets: [PromptsTemplates] {
        PromptsTemplates.allCases.filter { $0 != .custom }
    }

    var body: some View {
        Form {
            if !model.isPackageAvailable {
                packageMissingSection
            }

            statusSection
            inputSection
            actionsSection

            if !model.output.isEmpty {
                outputSection
            }

            if model.metrics.loadSeconds > 0 || model.metrics.emittedChunks > 0 {
                metricsSection
            }
        }
        .navigationTitle("LiteRT Gemma Spike")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var packageMissingSection: some View {
        Section {
            Label("LiteRT package not linked", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Add the Swift package via Xcode (File > Add Package Dependencies):\nhttps://github.com/john-rocky/swift-litert-lm\nthen select the LiteRTFoundation product for the VivaDicta target and run on a physical device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        } header: {
            Text("Setup required")
        }
    }

    private var statusSection: some View {
        Section {
            LabeledContent("Status", value: model.phase.label)
            if case .downloading(let fraction) = model.phase {
                ProgressView(value: fraction)
            }
        } footer: {
            Text("Gemma 4 E2B is a ~2.6 GB download on first load. Use Wi-Fi. Physical device only.")
        }
    }

    private var inputSection: some View {
        Section {
            Picker("Preset", selection: $model.selectedPreset) {
                ForEach(presets) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Menu("Load sample transcript") {
                ForEach(LiteRTSpikeSamples.all, id: \.name) { sample in
                    Button(sample.name) { model.transcript = sample.text }
                }
            }

            TextEditor(text: $model.transcript)
                .frame(minHeight: 120)
                .font(.callout)
        } header: {
            Text("Input")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task { await model.loadModel() }
            } label: {
                Label(
                    model.isModelLoaded ? "Model loaded" : "Load model",
                    systemImage: model.isModelLoaded ? "checkmark.circle" : "arrow.down.circle"
                )
            }
            .disabled(model.isBusy || model.isModelLoaded || !model.isPackageAvailable)

            Button {
                Task { await model.run() }
            } label: {
                Label("Run preset", systemImage: "play.circle")
            }
            .disabled(model.isBusy || !model.isModelLoaded)

            Button(role: .destructive) {
                model.unload()
            } label: {
                Label("Unload / reset", systemImage: "trash")
            }
            .disabled(model.isBusy)
        } header: {
            Text("Actions")
        }
    }

    private var outputSection: some View {
        Section {
            Text(model.output)
                .font(.callout)
                .textSelection(.enabled)
        } header: {
            Text("Output")
        }
    }

    private var metricsSection: some View {
        Section {
            LabeledContent("Load + compile", value: seconds(model.metrics.loadSeconds))
            LabeledContent("First token", value: seconds(model.metrics.firstTokenSeconds))
            LabeledContent("Throughput", value: "\(model.metrics.decodeTokensPerSecond.formatted(.number.precision(.fractionLength(1)))) chunk/s")
            LabeledContent("Chunks", value: "\(model.metrics.emittedChunks)")
            LabeledContent("Peak memory", value: megabytes(model.metrics.peakFootprintMB))
            LabeledContent("Memory delta", value: megabytes(model.metrics.deltaFootprintMB))
        } header: {
            Text("Metrics")
        } footer: {
            Text("Throughput counts stream chunks, not exact model tokens - treat as relative. Peak memory is phys_footprint (the jetsam metric).")
        }
    }

    private func seconds(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))s"
    }

    private func megabytes(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) MB"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        LiteRTSpikeView()
    }
}
#endif
