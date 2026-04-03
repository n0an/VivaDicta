//
//  WatchAppCoordinator.swift
//  VivaDictaWatch Watch App
//
//  Created by Anton Novoselov on 2026.04.03
//

import Foundation
import os

/// Coordinates communication between the watch app and its widget extension
/// using Darwin notifications and UserDefaults.
@MainActor
final class WatchAppCoordinator {
    static let shared = WatchAppCoordinator()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "AppCoordinator")

    private enum Keys {
        static let isRecording = "watchIsRecording"
    }

    private enum DarwinNotifications {
        static let toggleRecording = "com.antonnovoselov.VivaDicta.watch.toggleRecording" as CFString
        static let recordingStateChanged = "com.antonnovoselov.VivaDicta.watch.recordingStateChanged" as CFString
    }

    var onToggleRecordingRequested: (() -> Void)?

    var isRecording: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isRecording) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.isRecording)
            postDarwinNotification(DarwinNotifications.recordingStateChanged)
        }
    }

    private init() {
        registerForDarwinNotification(DarwinNotifications.toggleRecording) { [weak self] in
            Task { @MainActor in
                self?.logger.info("📡 Received toggle recording request from control")
                self?.onToggleRecordingRequested?()
            }
        }
    }

    func requestToggleRecording() {
        postDarwinNotification(DarwinNotifications.toggleRecording)
    }

    // MARK: - Darwin Notification Helpers

    private func postDarwinNotification(_ name: CFString) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name),
            nil, nil, true
        )
    }

    private func registerForDarwinNotification(_ name: CFString, callback: @escaping () -> Void) {
        let pointer = Unmanaged.passRetained(CallbackWrapper(callback)).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            pointer,
            { _, pointer, _, _, _ in
                guard let pointer else { return }
                let wrapper = Unmanaged<CallbackWrapper>.fromOpaque(pointer).takeUnretainedValue()
                wrapper.callback()
            },
            name,
            nil,
            .deliverImmediately
        )
    }
}

private final class CallbackWrapper {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
}
