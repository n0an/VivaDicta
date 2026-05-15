// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation

public enum TranscriptionProgressStage: Sendable, Equatable {
    case preparingAudio
    case detectingSpeech
    case transcribing

    public var detailText: String {
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

public struct TranscriptionProgressInfo: Sendable, Equatable {
    public let stage: TranscriptionProgressStage
    public let fractionCompleted: Double?

    public init(stage: TranscriptionProgressStage, fractionCompleted: Double? = nil) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted.map { min(max($0, 0), 1) }
    }

    public var detailText: String? {
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

public typealias TranscriptionProgressHandler = @Sendable (TranscriptionProgressInfo) async -> Void
