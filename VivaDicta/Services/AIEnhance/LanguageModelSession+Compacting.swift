//
//  LanguageModelSession+Compacting.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.09
//
//  Provides transcript builders and debug logging
//  for LanguageModelSession context window management.
//

import Foundation
import FoundationModels
import os

// MARK: - Transcript Helpers

@available(iOS 26, *)
extension Transcript {
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

// MARK: - Transcript Builder

@available(iOS 26, *)
extension Transcript {
    private static func segment(_ text: String) -> Transcript.Segment {
        .text(Transcript.TextSegment(content: text))
    }

    /// Builds a synthesized transcript with clean separation of concerns.
    ///
    /// Instead of stuffing note text and summaries into instructions,
    /// this creates structured entries:
    /// - `.instructions` = system prompt only
    /// - `.prompt` + `.response` = note context as a prior exchange
    /// - `.response` = optional summary as a prior model response
    static func buildFresh(
        instructions: String,
        notePrompt: String,
        noteAcknowledgment: String,
        summary: String? = nil
    ) -> Transcript {
        var entries: [Transcript.Entry] = [
            .instructions(.init(segments: [segment(instructions)], toolDefinitions: [])),
            .prompt(.init(segments: [segment(notePrompt)])),
            .response(.init(assetIDs: [], segments: [segment(noteAcknowledgment)]))
        ]

        if let summary, !summary.isEmpty {
            entries.append(
                .response(.init(assetIDs: [], segments: [segment("Summary of our earlier conversation: \(summary)")]))
            )
        }

        return Transcript(entries: entries)
    }

    /// Rebuilds a transcript after compaction: instructions + note + summary.
    /// The summary replaces all prior conversation turns.
    static func buildCompacted(
        instructions: String,
        notePrompt: String,
        summary: String
    ) -> Transcript {
        Transcript(entries: [
            .instructions(.init(segments: [segment(instructions)], toolDefinitions: [])),
            .prompt(.init(segments: [segment(notePrompt)])),
            .response(.init(assetIDs: [], segments: [segment(summary)]))
        ])
    }
}

// MARK: - Debug Logging

@available(iOS 26, *)
extension LanguageModelSession {
    #if DEBUG
    /// Logs the full session transcript (instructions, prompts, responses) for debugging.
    func logTranscript(label: String = "SESSION", logger: Logger? = nil) {
        let log: (String) -> Void = { message in
            if let logger {
                logger.logDebug(message)
            } else {
                print(message)
            }
        }

        log("=== FOUNDATION MODEL TRANSCRIPT [\(label)] ===")

        for entry in transcript {
            switch entry {
            case .instructions(let instructions):
                log("INSTRUCTIONS: \(instructions.segments.map { "\($0)" }.joined(separator: " "))")
            case .prompt(let prompt):
                log("PROMPT: \(prompt.segments.map { "\($0)" }.joined(separator: " "))")
            case .response(let response):
                log("RESPONSE: \(response.segments.map { "\($0)" }.joined(separator: " "))")
            case .toolCalls(let toolCalls):
                log("TOOL CALLS: \(toolCalls)")
            case .toolOutput(let toolOutput):
                log("TOOL OUTPUT: \(toolOutput)")
            @unknown default:
                log("UNKNOWN ENTRY: \(entry)")
            }
        }

        log("=== END TRANSCRIPT [\(label)] ===")
    }
    #endif
}
