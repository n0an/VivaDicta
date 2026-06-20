// Copyright © 2026 Anton Novoselov. All rights reserved.

import CoreGraphics
import Foundation
import AppGroup
@testable import VivaDicta

/// Hand-rolled mock of ``AppGroupBridge`` for `RecordViewModel` tests. Records
/// state pushed toward the keyboard and exposes the control callbacks so tests
/// can fire them - no process-global singleton involved.
@MainActor
final class MockAppGroupBridge: AppGroupBridge {
    var onStartRecordingRequested: (() -> Void)?
    var onStopRecordingRequested: (() -> Void)?
    var onCancelRecordingRequested: (() -> Void)?
    var onPauseRecordingRequested: (() -> Void)?
    var onResumeRecordingRequested: (() -> Void)?
    var onStartRecordingFromControl: (() -> Void)?
    var onVivaModeChanged: (() -> Void)?
    var onTextProcessingRequested: (() -> Void)?

    private(set) var recordingStates: [Bool] = []
    private(set) var audioLevels: [CGFloat] = []
    private(set) var transcriptionStatuses: [AppGroupCoordinator.TranscriptionStatus] = []
    private(set) var transcriptionErrors: [String] = []
    private(set) var sharedTranscribedTexts: [String] = []
    private(set) var obsidianHandoffs: [(url: URL, clipboardText: String)] = []
    private(set) var textProcessingResults: [String] = []
    private(set) var textProcessingErrors: [String] = []
    private(set) var refreshKeyboardSessionExpiryCalls: [Int] = []
    var stubPendingTextProcessing: (text: String, modeName: String, presetId: String?)?

    func updateRecordingState(_ isRecording: Bool) { recordingStates.append(isRecording) }
    func updateAudioLevel(_ level: CGFloat) { audioLevels.append(level) }
    func updateTranscriptionStatus(_ status: AppGroupCoordinator.TranscriptionStatus) { transcriptionStatuses.append(status) }
    func updateTranscriptionError(_ message: String) { transcriptionErrors.append(message) }
    func shareTranscribedText(_ text: String) { sharedTranscribedTexts.append(text) }
    func setPendingObsidianHandoff(url: URL, clipboardText: String) { obsidianHandoffs.append((url, clipboardText)) }
    func shareTextProcessingResult(_ text: String) { textProcessingResults.append(text) }
    func shareTextProcessingError(_ message: String) { textProcessingErrors.append(message) }
    func refreshKeyboardSessionExpiry(timeoutSeconds: Int) { refreshKeyboardSessionExpiryCalls.append(timeoutSeconds) }

    func getAndConsumePendingTextProcessing() -> (text: String, modeName: String, presetId: String?)? {
        defer { stubPendingTextProcessing = nil }
        return stubPendingTextProcessing
    }
}
