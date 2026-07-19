//
//  LanguageScoresView.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.07.19
//

import SwiftUI

/// A single language's identification score, ready for display.
///
/// Wraps one entry of the Whisper language-probability distribution with a
/// human-readable name and pre-formatted percentage. Kept as a plain value
/// type so sorting/formatting is unit-testable without SwiftUI.
struct LanguageScore: Identifiable, Equatable {
    /// Whisper language code (e.g. "en", "ru").
    let code: String
    /// Probability in `0...1`.
    let probability: Double

    var id: String { code }

    /// Localized display name for the language, falling back to the raw code
    /// when the locale can't resolve it (Whisper includes a few exotic codes).
    var displayName: String {
        Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    /// Probability formatted as a percentage with one fractional digit,
    /// e.g. `"72.4%"`.
    var formattedPercent: String {
        probability.formatted(.percent.precision(.fractionLength(1)))
    }

    /// Converts a raw probability dictionary into scores sorted by
    /// probability descending; ties break alphabetically by code so the
    /// ordering is stable.
    static func sorted(from probabilities: [String: Double]) -> [LanguageScore] {
        probabilities
            .map { LanguageScore(code: $0.key, probability: $0.value) }
            .sorted {
                if $0.probability != $1.probability {
                    return $0.probability > $1.probability
                }
                return $0.code < $1.code
            }
    }
}

/// Bottom sheet listing Whisper's language-identification scores for a
/// transcription, ordered by probability. Shown from the Transcription Detail
/// screen for local WhisperKit transcriptions made with auto language
/// detection.
struct LanguageScoresView: View {
    let probabilities: [String: Double]

    private var scores: [LanguageScore] {
        LanguageScore.sorted(from: probabilities)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(scores) { score in
                        scoreRow(score)
                    }
                } footer: {
                    Text("How confidently Whisper identified each language from the audio. A high score for a non-spoken language usually reflects the speaker's accent.")
                }
            }
            .navigationTitle("Language Scores")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func scoreRow(_ score: LanguageScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(score.displayName)
                    .font(.subheadline)

                Text(score.code)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(score.formattedPercent)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: score.probability)
                .tint(.accentColor)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LanguageScoresView(probabilities: [
        "en": 0.61,
        "ru": 0.29,
        "uk": 0.04,
        "pl": 0.02,
        "de": 0.01,
    ])
}
