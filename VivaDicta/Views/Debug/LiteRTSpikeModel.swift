//
//  LiteRTSpikeModel.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.06.20
//
//  Phase 0 spike (DEBUG only): measures on-device Gemma 4 E2B via the
//  LiteRT-LM runtime (john-rocky/swift-litert-lm). Goal is a go/no-go on
//  memory, latency, tokens/sec, and output quality on a real device before
//  any production provider work. See llmtemp/litert-gemma-integration-plan.md.
//
//  All LiteRT-LM calls are isolated behind `#if canImport(LiteRTFoundation)`
//  so the app compiles before the SPM package is added. Add the package via
//  Xcode (File > Add Package Dependencies: https://github.com/john-rocky/swift-litert-lm).
//
//  NOTE: the exact SDK symbol names below (LiteRTChat, .gemma4_E2B,
//  chat.stream, progress.fraction) come from the package README and must be
//  verified against the resolved SDK once the package is added.
//

import Foundation
import Darwin
import os

#if canImport(LiteRTFoundation)
import LiteRTFoundation
#endif

/// Fixed sample transcripts for repeatable spike runs across languages.
enum LiteRTSpikeSamples {
    static let englishMeeting = """
    so um I wanted to go over like three things first the the budget we need to \
    finalize it by friday actually no by thursday second the the hiring we should \
    interview at least four candidates and uh third the the launch date what do you \
    all think should we push it
    """

    static let russianNote = """
    короче я хотел обсудить пару моментов во первых нам нужно еще раз посмотреть \
    дизайн во вторых давайте определимся со сроками я думаю это займет где то неделю
    """

    static let codingSession = """
    okay so for this function um is it better to use a map and filter or should i \
    just stick with a for loop and also do you think we should make this async or is \
    it fine to keep it synchronous what would you recommend
    """

    static let all: [(name: String, text: String)] = [
        ("English meeting", englishMeeting),
        ("Russian note (e/e rule)", russianNote),
        ("Coding session", codingSession),
    ]
}

@MainActor
@Observable
final class LiteRTSpikeModel {
    enum Phase: Equatable {
        case idle
        case downloading(Double)
        case compiling
        case ready
        case generating
        case failed(String)

        var label: String {
            switch self {
            case .idle: "Idle"
            case .downloading(let f): "Downloading \(Int(f * 100))%"
            case .compiling: "Loading / compiling kernels..."
            case .ready: "Ready"
            case .generating: "Generating..."
            case .failed(let m): "Failed: \(m)"
            }
        }
    }

    /// Measured outcomes for one run. tokensPerSecond is approximate because the
    /// stream may chunk by characters/sub-tokens rather than model tokens.
    struct Metrics: Equatable {
        var loadSeconds: Double = 0
        var firstTokenSeconds: Double = 0
        var decodeTokensPerSecond: Double = 0
        var emittedChunks: Int = 0
        var baselineFootprintMB: Double = 0
        var peakFootprintMB: Double = 0

        var deltaFootprintMB: Double { max(0, peakFootprintMB - baselineFootprintMB) }
    }

    private(set) var phase: Phase = .idle
    private(set) var output: String = ""
    private(set) var metrics = Metrics()

    var selectedPreset: PromptsTemplates = .regular
    var transcript: String = LiteRTSpikeSamples.englishMeeting

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "LiteRTSpike")

    /// Whether the SPM package is linked. When false, the screen shows setup guidance.
    var isPackageAvailable: Bool {
        #if canImport(LiteRTFoundation)
        true
        #else
        false
        #endif
    }

    var isModelLoaded: Bool {
        switch phase {
        case .ready, .generating: true
        default: false
        }
    }

    var isBusy: Bool {
        switch phase {
        case .downloading, .compiling, .generating: true
        default: false
        }
    }

    #if canImport(LiteRTFoundation)
    private var chat: LiteRTChat?
    #endif

    /// Combined system + user prompt, mirroring the real enhancement pipeline:
    /// `PromptsTemplates.systemPrompt(with:)` as instructions, transcript wrapped
    /// in <TRANSCRIPT> tags as the user message.
    var resolvedPrompt: String {
        let system = PromptsTemplates.systemPrompt(with: selectedPreset.prompt)
        let user = "<TRANSCRIPT>\n\(transcript)\n</TRANSCRIPT>"
        return system + "\n\n" + user
    }

    func loadModel() async {
        #if canImport(LiteRTFoundation)
        guard chat == nil else { return }
        metrics.baselineFootprintMB = currentFootprintMB()
        let started = Date()
        phase = .downloading(0)
        do {
            // VERIFY against SDK: init case, progress closure, progress.fraction.
            let loaded = try await LiteRTChat(.gemma4_E2B) { [weak self] progress in
                Task { @MainActor in
                    guard let self else { return }
                    if progress.fraction >= 1.0 {
                        self.phase = .compiling
                    } else {
                        self.phase = .downloading(progress.fraction)
                    }
                }
            }
            chat = loaded
            metrics.loadSeconds = Date().timeIntervalSince(started)
            phase = .ready
            logger.log("LiteRT Gemma loaded in \(self.metrics.loadSeconds, format: .fixed(precision: 1))s")
        } catch {
            phase = .failed(error.localizedDescription)
            logger.error("LiteRT load failed: \(error.localizedDescription, privacy: .public)")
        }
        #else
        phase = .failed("LiteRTFoundation package not installed. Add swift-litert-lm via Xcode.")
        #endif
    }

    func run() async {
        #if canImport(LiteRTFoundation)
        guard let chat else {
            phase = .failed("Load the model first.")
            return
        }
        output = ""
        phase = .generating
        var chunks = 0
        var peak = currentFootprintMB()
        let started = Date()
        var firstChunkAt: Date?
        do {
            // VERIFY against SDK: stream(_:) signature and element type.
            for try await piece in chat.stream(resolvedPrompt) {
                if firstChunkAt == nil { firstChunkAt = Date() }
                output += piece
                chunks += 1
                peak = max(peak, currentFootprintMB())
            }
            let ended = Date()
            let firstAt = firstChunkAt ?? ended
            let decodeWindow = ended.timeIntervalSince(firstAt)
            metrics.firstTokenSeconds = firstAt.timeIntervalSince(started)
            metrics.emittedChunks = chunks
            metrics.decodeTokensPerSecond = decodeWindow > 0 ? Double(chunks) / decodeWindow : 0
            metrics.peakFootprintMB = peak
            phase = .ready
            logger.log("LiteRT run: \(chunks) chunks, \(self.metrics.decodeTokensPerSecond, format: .fixed(precision: 1)) chunk/s, peak \(Int(peak)) MB")
        } catch {
            phase = .failed(error.localizedDescription)
            logger.error("LiteRT run failed: \(error.localizedDescription, privacy: .public)")
        }
        #else
        phase = .failed("LiteRTFoundation package not installed.")
        #endif
    }

    func unload() {
        #if canImport(LiteRTFoundation)
        chat = nil
        #endif
        phase = .idle
        output = ""
        metrics = Metrics()
    }
}

/// App memory footprint in MB via `phys_footprint` (the jetsam-relevant metric).
@MainActor
private func currentFootprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), reboundPointer, &count)
        }
    }
    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.phys_footprint) / 1_048_576.0
}
