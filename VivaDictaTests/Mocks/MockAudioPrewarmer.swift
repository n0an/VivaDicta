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

    var stubStartRealCaptureError: Error?
    private(set) var startRealCaptureCallCount = 0
    private(set) var stopRealCaptureCallCount = 0
    private(set) var rescheduleSessionTimeoutCallCount = 0
    private(set) var lastCaptureURL: URL?

    func startRealCapture(to url: URL) throws {
        startRealCaptureCallCount += 1
        lastCaptureURL = url
        if let stubStartRealCaptureError { throw stubStartRealCaptureError }
    }

    func stopRealCapture() { stopRealCaptureCallCount += 1 }
    func rescheduleSessionTimeout() { rescheduleSessionTimeoutCallCount += 1 }
}
