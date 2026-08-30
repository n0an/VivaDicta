// Copyright © 2026 Anton Novoselov. All rights reserved.

import CoreGraphics
import Foundation
import AppGroup

/// The app-group coordination surface ``RecordViewModel`` depends on - publishing
/// recording/transcription state to the keyboard extension and receiving its
/// control callbacks. ``AppGroupCoordinator`` is the production conformance;
/// tests inject a mock so the view model can be constructed and its recording
/// flow exercised without touching the process-global singleton.
@MainActor
protocol AppGroupBridge: AnyObject {
    // Keyboard -> app control callbacks (set during setup).
    var onStartRecordingRequested: (() -> Void)? { get set }
    var onStopRecordingRequested: (() -> Void)? { get set }
    var onCancelRecordingRequested: (() -> Void)? { get set }
    var onPauseRecordingRequested: (() -> Void)? { get set }
    var onResumeRecordingRequested: (() -> Void)? { get set }
    var onStartRecordingFromControl: (() -> Void)? { get set }
    var onVivaModeChanged: (() -> Void)? { get set }
    var onTextProcessingRequested: (() -> Void)? { get set }

    // App -> keyboard state + results.
    func updateRecordingState(_ isRecording: Bool)
    func updateAudioLevel(_ level: CGFloat)
    func updateTranscriptionStatus(_ status: AppGroupCoordinator.TranscriptionStatus)
    func updateTranscriptionError(_ message: String)
    func shareTranscribedText(_ text: String)
    func setPendingObsidianHandoff(url: URL, clipboardText: String)
    func shareTextProcessingResult(_ text: String)
    func shareTextProcessingError(_ message: String)
    func refreshKeyboardSessionExpiry(timeoutSeconds: Int)
    func getAndConsumePendingTextProcessing() -> (text: String, modeName: String, presetId: String?)?
    func getAndConsumePendingVoiceInstruction() -> (targetText: String, modeName: String)?
    func clearPendingVoiceInstruction()
}

extension AppGroupCoordinator: AppGroupBridge {}
