// Copyright © 2026 Anton Novoselov. All rights reserved.

import AVFoundation
import Foundation
@testable import VivaDicta

/// Hand-rolled mock of ``AudioPrewarmer`` for `RecordViewModel` tests - lets the
/// recording flow run without a live AVAudioEngine. Stubs state and counts calls.
@MainActor
final class MockAudioPrewarmer: AudioPrewarmer {
    var isSessionActive: Bool = false
    var audioSessionTimeout: Int = 60
    var currentAudioLevel: Float = 0.0
    var audioEngine: AVAudioEngine?

    var onInterruption: (@MainActor () -> Void)?

    var stubStartRealCaptureError: Error?
    private(set) var startRealCaptureCallCount = 0
    private(set) var stopRealCaptureCallCount = 0
    private(set) var rescheduleSessionTimeoutCallCount = 0
    private(set) var lastCaptureURL: URL?
    /// Whether the last capture asked for a realtime PCM stream, and the
    /// continuation it was handed - the streaming keyboard path is asserted on
    /// both.
    private(set) var lastPCMStream: AsyncStream<Data>.Continuation?
    var didRequestPCMStream: Bool { lastPCMStream != nil }

    func startRealCapture(to url: URL, pcmStream: AsyncStream<Data>.Continuation?) throws {
        startRealCaptureCallCount += 1
        lastCaptureURL = url
        lastPCMStream = pcmStream
        if let stubStartRealCaptureError { throw stubStartRealCaptureError }
    }

    func stopRealCapture() {
        stopRealCaptureCallCount += 1
        lastPCMStream?.finish()
    }
    func rescheduleSessionTimeout() { rescheduleSessionTimeoutCallCount += 1 }

    /// Test helper: simulate the audio session being interrupted mid-capture.
    func fireInterruption() {
        onInterruption?()
    }
}
