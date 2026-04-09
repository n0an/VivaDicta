//
//  LanguageModelSession+Compacting.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//
//  Adapted from Apple's AIPlaybook sample project.
//  Provides reactive compaction and preemptive summarization
//  for LanguageModelSession context window management.
//

import Foundation
import FoundationModels

// MARK: - Transcript Helpers

@available(iOS 26, *)
extension Transcript {
    /// Extracts instructions from the transcript, stripping tool definitions.
    ///
    /// Tool definitions should not be imported into a compacted session;
    /// supply a fresh `tools` array on session rebuild instead.
    func getInstructions() -> Transcript.Entry? {
        guard let first = self.first else { return nil }

        if case let .instructions(text) = first {
            return .instructions(.init(segments: text.segments, toolDefinitions: []))
        }

        return nil
    }

    /// Extracts user prompts and model responses, ignoring tool calls and internal entries.
    func getMessages() -> [Transcript.Entry] {
        var result = [Transcript.Entry]()

        for item in self.dropFirst() {
            switch item {
            case .prompt, .response:
                result.append(item)
            default:
                continue
            }
        }

        return result
    }
}

// MARK: - Session Compaction

@available(iOS 26, *)
extension LanguageModelSession {

    #if swift(>=6.3)
    private static var defaultMaxCharacters: Int {
        SystemLanguageModel.default.contextSize
    }
    #else
    private static var defaultMaxCharacters: Int {
        4096
    }
    #endif

    /// Creates a compacted session by keeping instructions and as many recent entries as fit.
    ///
    /// Greedy keep-recent algorithm: walks transcript backwards, adding entries
    /// until the character budget is exhausted. Instructions are always preserved.
    ///
    /// - Parameters:
    ///   - maxCharacters: Character budget for the compacted transcript.
    ///   - tools: Tools to supply to the new session.
    /// - Returns: A new session with a compacted transcript.
    func compacted(maxCharacters: Int = defaultMaxCharacters, tools: [any Tool] = []) -> LanguageModelSession {
        guard let first = transcript.getInstructions() else {
            return self
        }

        var selected = [first]
        var totalLength = String(describing: first).count

        var recentEntries = [Transcript.Entry]()

        // Walk backwards — most recent entries are most relevant
        for entry in transcript.getMessages().reversed() {
            let length = String(describing: entry).count
            guard totalLength + length <= maxCharacters else { break }
            recentEntries.insert(entry, at: 0)
            totalLength += length
        }

        selected.append(contentsOf: recentEntries)

        #if DEBUG
        print("DEBUG: Compacted transcript to \(selected.count) entries")
        #endif

        return LanguageModelSession(tools: tools, transcript: Transcript(entries: selected))
    }

    /// Preemptively summarizes the conversation when context usage exceeds a fill threshold.
    ///
    /// Process:
    /// 1. Check whether token usage exceeds `fillAmount` of the context window.
    /// 2. Keep the first transcript entry (instructions) as anchor context.
    /// 3. Summarize remaining entries into a bounded summary using a separate session.
    /// 4. Rebuild a fresh session with `Start + Summary` as instructions.
    ///
    /// - Parameters:
    ///   - fillAmount: Context fill ratio (0-1) that triggers compaction. Default 0.7.
    ///   - targetContextTokens: Approximate token target for rebuilt context. Default 1000.
    ///   - tools: Tools to supply to the new session.
    /// - Returns: A new compacted session, or `self` if compaction is not needed.
    func preemptivelySummarizedIfNeeded(
        over fillAmount: Double = 0.7,
        targetContextTokens: Int = 1000,
        tools: [any Tool] = []
    ) async throws -> LanguageModelSession {
        let targetContextTokens = max(1, targetContextTokens)
        let fill = min(max(fillAmount, 0), 1)

        #if swift(>=6.3)
        let triggerTokens = Int(Double(SystemLanguageModel.default.contextSize) * fill)
        #else
        let triggerTokens = Int(Double(4096) * fill)
        #endif

        let usedTokens: Int

        #if swift(>=6.3)
        if #available(iOS 26.4, macOS 26.4, *) {
            usedTokens = try await SystemLanguageModel.default.tokenCount(for: transcript)
        } else {
            usedTokens = String(describing: transcript).count / 2
        }
        #else
        usedTokens = String(describing: transcript).count / 2
        #endif

        // Below threshold — no compaction needed
        guard usedTokens > triggerTokens else { return self }

        #if DEBUG
        print("DEBUG: Preemptive compaction triggered (\(usedTokens)/\(triggerTokens) tokens)")
        #endif

        guard let first = transcript.getInstructions() else {
            return self
        }

        let firstText = String(describing: first)

        // Build summary source from conversation messages (recency-biased)
        let summarySource = transcript.getMessages()
            .map(String.init)
            .joined(separator: "\n\n")
            .suffix(triggerTokens * 3)

        // Calculate summary budget
        let frame = "Instructions: \(firstText)"
        let summaryCharacterLimit = max(0, targetContextTokens * 3 - frame.count)
        let summary: String

        if summarySource.isEmpty || summaryCharacterLimit == 0 {
            summary = ""
        } else {
            let summarizer = LanguageModelSession(
                instructions: "Summarize the entire input from beginning to end, covering the whole document (not just the end), preserving key facts. Be concise. Hard maximum: \(summaryCharacterLimit) characters."
            )
            let response = try await summarizer.respond(to: "Summarize this text: \(summarySource)")
            summary = String(response.content.prefix(summaryCharacterLimit))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            #if DEBUG
            print("DEBUG: Preemptive summary: \(summary)")
            #endif
        }

        let instructions = """
        Start:
        \(firstText)
        Summary:
        \(summary)
        """

        // Hard upper bound safety ceiling
        let hardLimitCharacters = Int(Double(targetContextTokens * 3) * 1.5)
        let clippedInstructions = String(instructions.prefix(hardLimitCharacters))

        return LanguageModelSession(tools: tools, instructions: clippedInstructions)
    }
}
