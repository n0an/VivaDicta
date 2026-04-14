//
//  SpeakerDiarizationFormatter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

struct SpeakerTurn: Hashable, Sendable {
    let speakerID: String?
    let text: String
}

enum SpeakerDiarizationFormatter {
    static func format(_ turns: [SpeakerTurn]) -> String? {
        var mergedTurns = [MergedTurn]()
        var lastResolvedSpeakerID: String?
        var unknownSpeakerCount = 0

        for turn in turns {
            let normalizedText = normalize(text: turn.text)
            guard normalizedText.isEmpty == false else {
                continue
            }

            let resolvedSpeakerID: String
            if let normalizedSpeakerID = normalize(speakerID: turn.speakerID) {
                resolvedSpeakerID = normalizedSpeakerID
            } else if let lastResolvedSpeakerID {
                resolvedSpeakerID = lastResolvedSpeakerID
            } else {
                resolvedSpeakerID = "unknown-\(unknownSpeakerCount)"
                unknownSpeakerCount += 1
            }

            if let lastIndex = mergedTurns.indices.last,
               mergedTurns[lastIndex].speakerID == resolvedSpeakerID {
                mergedTurns[lastIndex].text += " " + normalizedText
            } else {
                mergedTurns.append(MergedTurn(speakerID: resolvedSpeakerID, text: normalizedText))
            }

            lastResolvedSpeakerID = resolvedSpeakerID
        }

        guard mergedTurns.isEmpty == false else {
            return nil
        }

        var speakerLabels = [String: String]()
        var nextSpeakerIndex = 0

        return mergedTurns
            .map { turn in
                let label = speakerLabels[turn.speakerID] ?? {
                    let newLabel = "Speaker \(speakerLetters(for: nextSpeakerIndex))"
                    speakerLabels[turn.speakerID] = newLabel
                    nextSpeakerIndex += 1
                    return newLabel
                }()
                return "\(label): \(turn.text)"
            }
            .joined(separator: "\n\n")
    }

    private static func normalize(text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalize(speakerID: String?) -> String? {
        guard let speakerID else {
            return nil
        }

        let trimmedSpeakerID = speakerID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSpeakerID.isEmpty ? nil : trimmedSpeakerID
    }

    private static func speakerLetters(for index: Int) -> String {
        precondition(index >= 0)

        var remaining = index
        var letters = ""

        repeat {
            let letterIndex = remaining % 26
            let scalarValue = UnicodeScalar(65 + letterIndex)!
            letters = String(scalarValue) + letters
            remaining = (remaining / 26) - 1
        } while remaining >= 0

        return letters
    }

    private struct MergedTurn: Hashable, Sendable {
        let speakerID: String
        var text: String
    }
}
