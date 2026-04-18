//
//  RecordAndReturnTranscriptionIntent.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.18
//

import AppIntents
import Foundation

struct RecordAndReturnTranscriptionIntent: AppIntent {
    static let title: LocalizedStringResource = "Record and Get Note"
    static let description = IntentDescription(
        "Starts recording in VivaDicta, waits for you to stop, and returns the transcribed note for use in other shortcut actions.",
        categoryName: "Notes",
        searchKeywords: ["record", "dictate", "transcribe", "note", "obsidian"],
        resultValueName: "Recorded Note"
    )

    static let openAppWhenRun: Bool = true

    /// Overall wait budget for the whole flow: user recording + transcription + optional AI enhancement.
    private static let maxWaitSeconds: TimeInterval = 180

    @Dependency var dataController: DataController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<TranscriptionEntity> & ProvidesDialog {
        let coordinator = AppGroupCoordinator.shared
        let startTime = Date()
        let previousLatestId = try? dataController.transcriptions(limit: 1).first?.id

        if !coordinator.isRecording && coordinator.transcriptionStatus == .idle {
            coordinator.requestStartRecordingFromControl()
        }

        let entity = try await waitForNewTranscription(
            after: startTime,
            previousLatestId: previousLatestId,
            coordinator: coordinator
        )

        return .result(
            value: entity,
            dialog: "\(entity.text(withPrefix: 80))"
        )
    }

    @MainActor
    private func waitForNewTranscription(
        after startTime: Date,
        previousLatestId: UUID?,
        coordinator: AppGroupCoordinator
    ) async throws -> TranscriptionEntity {
        let deadline = Date().addingTimeInterval(Self.maxWaitSeconds)

        while Date() < deadline {
            try Task.checkCancellation()

            if coordinator.transcriptionStatus == .error {
                let message = coordinator.getAndConsumeTranscriptionErrorMessage()
                    ?? String(localized: "Transcription failed.")
                throw RecordAndReturnIntentError.failed(message)
            }

            if let latest = try dataController.transcriptions(limit: 1).first,
               latest.id != previousLatestId,
               latest.timestamp > startTime,
               coordinator.transcriptionStatus == .completed || coordinator.transcriptionStatus == .idle {
                return latest.entity
            }

            try await Task.sleep(for: .milliseconds(500))
        }

        throw RecordAndReturnIntentError.timedOut
    }
}

enum RecordAndReturnIntentError: Error, CustomLocalizedStringResourceConvertible {
    case failed(String)
    case timedOut

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .failed(let message):
            "Recording failed: \(message)"
        case .timedOut:
            "Timed out waiting for the recording to finish."
        }
    }
}
