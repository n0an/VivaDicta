//
//  MLXSpikeView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.24
//
//  DEBUG-only verification harness for running MLX models on iOS. MLX works on
//  macOS (VivaDictaMac uses it), but on iOS mlx-swift has historically had
//  Metal kernel-bundle (default.metallib) emission issues - so this spike's
//  whole purpose is to confirm MLX actually loads + generates on a physical
//  device before we build a real provider. Physical device only.
//
//  Mirrors VivaDictaMac's MLXLocalModelService code path verbatim (mlx-swift-lm
//  pinned to the same revision): LLMModelFactory.loadContainer ->
//  ModelContainer.perform { MLXLMCommon.generate }.
//

import SwiftUI
import os

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

@MainActor
@Observable
final class MLXSpike {
    struct Model: Identifiable, Hashable {
        let id: String        // mlx-community HF repo id
        let name: String
        let size: String
    }

    static let models: [Model] = [
        Model(id: "mlx-community/Llama-3.2-1B-Instruct-4bit", name: "Llama 3.2 1B", size: "~0.7 GB"),
        Model(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", name: "Llama 3.2 3B", size: "~1.8 GB"),
        Model(id: "mlx-community/Qwen3-4B-4bit", name: "Qwen3 4B", size: "~2.3 GB"),
    ]

    private(set) var status = "Idle"
    private(set) var output = ""
    private(set) var isRunning = false
    private(set) var tokensPerSecond: Double = 0

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "MLXSpike")

    func run(modelID: String, prompt: String) async {
        guard !isRunning else { return }
        isRunning = true
        output = ""
        tokensPerSecond = 0
        defer { isRunning = false }

        #if canImport(MLXLLM)
        do {
            status = "Loading \(modelID) (downloads on first run, then compiles Metal kernels)…"
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: ModelConfiguration(id: modelID)
            ) { progress in
                Task { @MainActor in
                    self.status = "Downloading… \(Int(progress.fractionCompleted * 100))%"
                }
            }

            status = "Generating…"
            let systemPrompt = "You clean up a speech-to-text transcript. Output only the cleaned text, never a reply."
            let userPrompt = prompt
            // MLX honors enable_thinking:false for reasoning-capable templates (Qwen).
            let additionalContext: [String: any Sendable]? =
                modelID.lowercased().contains("qwen") ? ["enable_thinking": false] : nil

            let start = Date()
            // Build UserInput inside perform so only Sendable values cross the
            // @Sendable boundary (UserInput itself is non-Sendable).
            let result: (text: String, chunks: Int) = try await container.perform { (context: ModelContext) in
                let chat: [Chat.Message] = [
                    .init(role: .system, content: systemPrompt),
                    .init(role: .user, content: userPrompt),
                ]
                let userInput = UserInput(chat: chat, additionalContext: additionalContext)
                let lmInput = try await context.processor.prepare(input: userInput)
                let parameters = GenerateParameters(temperature: 0.3, topP: 0.95, repetitionPenalty: 1.05)
                let stream = try MLXLMCommon.generate(input: lmInput, parameters: parameters, context: context)
                var text = ""
                var chunks = 0
                for try await generation in stream {
                    if case .chunk(let chunk) = generation {
                        text += chunk
                        chunks += 1
                    }
                }
                return (text, chunks)
            }
            let dt = Date().timeIntervalSince(start)

            output = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            tokensPerSecond = dt > 0 ? Double(result.chunks) / dt : 0
            status = "Done - \(result.chunks) chunks in \(dt.formatted(.number.precision(.fractionLength(1))))s"
            logger.info("MLX spike generated \(result.chunks) chunks for \(modelID)")
        } catch {
            status = "Error: \(error.localizedDescription)"
            logger.error("MLX spike failed: \(error.localizedDescription)")
        }
        #else
        status = "MLX is not available in this build."
        #endif
    }
}

struct MLXSpikeView: View {
    @State private var spike = MLXSpike()
    @State private var modelID = MLXSpike.models[0].id
    @State private var prompt = "Rewrite this cleanly: um, so like, the meeting is, uh, tomorrow at noon okay."

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: $modelID) {
                    ForEach(MLXSpike.models) { model in
                        Text("\(model.name) (\(model.size))").tag(model.id)
                    }
                }
                .disabled(spike.isRunning)
            } footer: {
                Text("MLX on the GPU. First run downloads the model from mlx-community and compiles Metal kernels. Physical device only - MLX may fail to bundle its Metal lib on iOS.")
            }

            Section("Prompt") {
                TextField("Prompt", text: $prompt, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button {
                    Task { await spike.run(modelID: modelID, prompt: prompt) }
                } label: {
                    if spike.isRunning {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Running…")
                        }
                    } else {
                        Text("Run")
                    }
                }
                .disabled(spike.isRunning || prompt.isEmpty)
            }

            Section("Status") {
                Text(spike.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if spike.tokensPerSecond > 0 {
                    Text("\(spike.tokensPerSecond, format: .number.precision(.fractionLength(1))) chunks/s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !spike.output.isEmpty {
                Section("Output") {
                    Text(spike.output)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("MLX Spike")
        .navigationBarTitleDisplayMode(.inline)
    }
}
