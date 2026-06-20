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
//  Drives the shared `LiteRTModelManager` (the production engine layer) so the
//  spike measures the real code path rather than a parallel implementation.
//  Physical device only - the Simulator has no Metal GPU and falls back to CPU.
//

import Foundation
import os

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

    /// Combined system + user prompt, mirroring the real enhancement pipeline:
    /// `PromptsTemplates.systemPrompt(with:)` as instructions, transcript wrapped
    /// in <TRANSCRIPT> tags as the user message.
    var resolvedPrompt: String {
        let system = PromptsTemplates.systemPrompt(with: selectedPreset.prompt)
        let user = "<TRANSCRIPT>\n\(transcript)\n</TRANSCRIPT>"
        return system + "\n\n" + user
    }

    func loadModel() async {
        metrics.baselineFootprintMB = LiteRTModelManager.memoryFootprintMB()
        let started = Date()
        phase = .downloading(0)
        do {
            try await LiteRTModelManager.shared.ensureLoaded { [weak self] fraction in
                Task { @MainActor in
                    guard let self else { return }
                    self.phase = fraction >= 1.0 ? .compiling : .downloading(fraction)
                }
            }
            metrics.loadSeconds = Date().timeIntervalSince(started)
            metrics.peakFootprintMB = max(metrics.peakFootprintMB, LiteRTModelManager.memoryFootprintMB())
            phase = .ready
            logger.logInfo("LiteRT Gemma loaded in \(metrics.loadSeconds.formatted(.number.precision(.fractionLength(1))))s")
        } catch {
            phase = .failed(error.localizedDescription)
            logger.logError("LiteRT load failed: \(error.localizedDescription)")
        }
    }

    func run() async {
        guard isModelLoaded else {
            phase = .failed("Load the model first.")
            return
        }
        output = ""
        phase = .generating
        var chunks = 0
        var peak = LiteRTModelManager.memoryFootprintMB()
        let started = Date()
        var firstChunkAt: Date?
        do {
            let stream = try await LiteRTModelManager.shared.stream(prompt: resolvedPrompt)
            for try await piece in stream {
                if firstChunkAt == nil { firstChunkAt = Date() }
                output += piece
                chunks += 1
                peak = max(peak, LiteRTModelManager.memoryFootprintMB())
            }
            let ended = Date()
            let firstAt = firstChunkAt ?? ended
            let decodeWindow = ended.timeIntervalSince(firstAt)
            metrics.firstTokenSeconds = firstAt.timeIntervalSince(started)
            metrics.emittedChunks = chunks
            metrics.decodeTokensPerSecond = decodeWindow > 0 ? Double(chunks) / decodeWindow : 0
            metrics.peakFootprintMB = max(metrics.peakFootprintMB, peak)
            phase = .ready
            logger.logInfo("LiteRT run: \(chunks) chunks, peak \(Int(peak)) MB")
        } catch {
            phase = .failed(error.localizedDescription)
            logger.logError("LiteRT run failed: \(error.localizedDescription)")
        }
    }

    func unload() {
        Task { await LiteRTModelManager.shared.unload() }
        phase = .idle
        output = ""
        metrics = Metrics()
    }
}
