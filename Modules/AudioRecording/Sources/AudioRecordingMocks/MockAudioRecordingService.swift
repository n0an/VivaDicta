// Copyright © 2026 Anton Novoselov. All rights reserved.

import Foundation
import AudioRecording
import TestUtilities

/// Test double for `AudioRecordingService`. Records calls so tests can
/// assert state transitions; stubs return values via `Result?` so a missing
/// stub records a Swift Testing issue rather than crashing silently.
///
/// ## Usage
///
/// ```swift
/// let recorder = MockAudioRecordingService()
/// recorder.stubStartRecording = .success(())
/// let sut = RecordViewModel(audioRecorder: recorder, ...)
/// try sut.beginRecording()
/// #expect(recorder.startRecordingCallCount == 1)
/// ```
@MainActor
public final class MockAudioRecordingService: AudioRecordingService {

    public init() {}

    public var stubIsRecording = false
    public var stubCurrentTime: TimeInterval = 0
    public var stubCurrentAudioPower: Float = -160

    public var stubStartRecording: Result<Void, Error>?
    public var stubStopRecording: URL?

    public private(set) var startRecordingCallCount = 0
    public private(set) var stopRecordingCallCount = 0
    public private(set) var capturedStartURL: URL?
    public private(set) var capturedStartSettings: [String: Any]?

    public var onDidFinishUnsuccessfully: (@MainActor () -> Void)?

    public var isRecording: Bool { stubIsRecording }
    public var currentTime: TimeInterval { stubCurrentTime }
    public var currentAudioPower: Float { stubCurrentAudioPower }

    /// Test helper: simulate the underlying recorder reporting an
    /// unsuccessful finish, invoking the wired-up consumer callback.
    public func fireDidFinishUnsuccessfully() {
        onDidFinishUnsuccessfully?()
    }

    public func startRecording(to url: URL, settings: [String: Any]) throws {
        startRecordingCallCount += 1
        capturedStartURL = url
        capturedStartSettings = settings
        try stubStartRecording.evaluate()
    }

    public func stopRecording() -> URL? {
        stopRecordingCallCount += 1
        return stubStopRecording
    }
}
