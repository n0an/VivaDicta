//
//  CoreMLQwenSpikeView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.23
//
//  DEBUG-only verification harness for on-device Qwen3.5 via CoreML-LLM.
//  Downloads the model, loads it on the ANE, and generates a test prompt so we
//  can confirm the low-level Qwen35MLKVGenerator flow actually produces text on
//  a physical device before wiring a full provider. Physical device only - the
//  Simulator has no real ANE path.
//

import SwiftUI
import LocalLLM

struct CoreMLQwenSpikeView: View {
    @State private var spike = CoreMLQwenSpike()
    @State private var variant: CoreMLQwenSpike.Variant = .qwen2B
    @State private var prompt = "Rewrite this cleanly: um, so like, the meeting is, uh, tomorrow at noon okay."

    var body: some View {
        Form {
            Section {
                Picker("Variant", selection: $variant) {
                    ForEach(CoreMLQwenSpike.Variant.allCases) { variant in
                        Text("\(variant.displayName) (\(variant.approxSize))").tag(variant)
                    }
                }
                .disabled(spike.isRunning)
            } footer: {
                Text("Qwen3.5 on-device via CoreML (ANE). First run downloads the model and compiles chunks - can take minutes. Physical device only.")
            }

            Section("Prompt") {
                TextField("Prompt", text: $prompt, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button {
                    Task { await spike.run(variant: variant, prompt: prompt) }
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
                    Text("\(spike.tokensPerSecond, format: .number.precision(.fractionLength(1))) tok/s")
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
        .navigationTitle("Qwen CoreML Spike")
        .navigationBarTitleDisplayMode(.inline)
    }
}
