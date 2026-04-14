//
//  TranscriptionProgressInfo.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14.
//

import Foundation

enum TranscriptionProgressStage: Sendable, Equatable {
    case preparingAudio
    case detectingSpeech
    case transcribing

    var detailText: String {
        switch self {
        case .preparingAudio:
            return "Preparing audio..."
        case .detectingSpeech:
            return "Detecting speech..."
        case .transcribing:
            return "Transcribing..."
        }
    }
}

struct TranscriptionProgressInfo: Sendable, Equatable {
    let stage: TranscriptionProgressStage
    let fractionCompleted: Double?

    init(stage: TranscriptionProgressStage, fractionCompleted: Double? = nil) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted.map { min(max($0, 0), 1) }
    }

    var detailText: String? {
        switch stage {
        case .transcribing:
            if let fractionCompleted {
                return "\(fractionCompleted.formatted(.percent.precision(.fractionLength(0)))) complete"
            }
            return nil
        default:
            return stage.detailText
        }
    }
}

typealias TranscriptionProgressHandler = @Sendable (TranscriptionProgressInfo) async -> Void
