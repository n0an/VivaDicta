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
final class WatchAppCoordinator: NSObject {
    static let shared = WatchAppCoordinator()

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.watchkitapp",
                                category: "AppCoordinator")

    private nonisolated(unsafe) static let toggleRecordingNotification = "com.antonnovoselov.VivaDicta.watch.toggleRecording" as CFString

    var onToggleRecordingRequested: (() -> Void)?

    private override init() {
        super.init()
        setupNotificationObservers()
    }

    // MARK: - Darwin Notification Helpers

    nonisolated private func postDarwinNotification(_ name: CFString) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name),
            nil, nil, true
        )
    }

    nonisolated private func setupNotificationObservers() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let coordinator = Unmanaged<WatchAppCoordinator>.fromOpaque(observer).takeUnretainedValue()
                coordinator.handleToggleRecordingNotification()
            },
            Self.toggleRecordingNotification,
            nil,
            .deliverImmediately
        )
    }

    nonisolated private func handleToggleRecordingNotification() {
        Task { @MainActor in
            logger.info("📡 Received toggle recording request from control")
            onToggleRecordingRequested?()
        }
    }
}
