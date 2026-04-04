//
//  MockWatchAudioRecorder.swift
//  VivaDictaWatch Watch AppTests
//
//  Created by Anton Novoselov on 2026.04.04
//

import Foundation
@testable import VivaDictaWatch_Watch_App

final class MockWatchAudioRecorder: WatchAudioRecorderProtocol {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    var isRecording: Bool = false
    var currentTime: TimeInterval = 0

    var shouldThrowOnStart = false
    var mockFileURL: URL = FileManager.default.temporaryDirectory
        .appending(path: "mock-recording.wav")

    func startRecording() throws -> URL {
        startCallCount += 1
        if shouldThrowOnStart {
            throw NSError(domain: "WatchAudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Mock recording error"])
        }
        isRecording = true
        return mockFileURL
    }

    func stopRecording() -> URL? {
        stopCallCount += 1
        guard isRecording else { return nil }
        isRecording = false
        return mockFileURL
    }
}
