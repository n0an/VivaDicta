//
//  OnDeviceModelMemory.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.27
//
//  Keeps at most ONE on-device LLM resident in RAM and frees it under memory
//  pressure / on background.
//
//  The three on-device runtimes each have an independent singleton manager that
//  loads a ~1-2 GB model and never releases it on its own:
//    - LiteRTModelManager   (Gemma, Metal GPU)
//    - LocalMLXModelManager (MLX, Metal GPU)
//    - CoreMLQwenModelManager (Qwen, ANE)
//  Because they don't coordinate, using models from two runtimes in one session
//  leaves both resident (2-3 models -> 3-5 GB), and nothing frees them under
//  memory pressure, so iOS jetsams the app instead. This centralizes:
//    1. single-resident: loading one runtime unloads the others;
//    2. memory-pressure + background unload.
//
//  `unload()` is safe to call on a manager that is mid-generation: the in-flight
//  task holds its own reference, so the model just deallocates once it finishes.
//

import Foundation
import os
import AICore
import LocalLLM

final class OnDeviceModelMemory: @unchecked Sendable {
    static let shared = OnDeviceModelMemory()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "OnDeviceModelMemory")
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    private init() {
        startMemoryPressureMonitor()
    }

    /// Activate the memory-pressure monitor (call once early in app launch). The
    /// real work happens in `init`; this just gives launch a clear hook and forces
    /// the singleton to exist so the monitor is armed.
    func activate() {}

    /// Ensure only `runtime` may be resident: unload the other two on-device
    /// runtimes. Call right before loading/generating with `runtime`.
    func ensureOnlyResident(_ runtime: AIProvider.LocalRuntime) async {
        if runtime != .liteRT { await LiteRTModelManager.shared.unload() }
        if runtime != .coreML { await CoreMLQwenModelManager.shared.unload() }
        if runtime != .mlx { await LocalMLXModelManager.shared.unload() }
    }

    /// Free every on-device LLM from RAM (memory pressure, or background with no
    /// active keyboard session).
    func unloadAll(reason: String) async {
        logger.logInfo("Unloading all on-device LLMs (\(reason))")
        await LiteRTModelManager.shared.unload()
        await CoreMLQwenModelManager.shared.unload()
        await LocalMLXModelManager.shared.unload()
    }

    private func startMemoryPressureMonitor() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.logger.logError("Memory pressure detected - freeing on-device LLMs")
            Task { await self.unloadAll(reason: "memory pressure") }
        }
        source.resume()
        memoryPressureSource = source
    }
}
