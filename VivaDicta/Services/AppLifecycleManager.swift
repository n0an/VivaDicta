//
//  AppLifecycleManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import UIKit
import os

/// Manages app lifecycle state and provides heartbeat updates for the keyboard extension
class AppLifecycleManager {

    // MARK: - Properties
    private var heartbeatTimer: Timer?
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AppLifecycleManager")
    private let sharedDefaults: UserDefaults?
    
    static let shared = AppLifecycleManager()

    // MARK: - Initialization
    private init() {
        sharedDefaults = UserDefaults(suiteName: AppGroupConfig.appGroupId)
        setupNotificationObservers()
        logger.info("🔄 AppLifecycleManager initialized")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    /// Start tracking app lifecycle and heartbeat
    func startTracking() {
        logger.info("🔄 Starting app lifecycle tracking")
        updateAppActiveState(true)
        startHeartbeat()
    }

    /// Stop tracking app lifecycle and heartbeat
    func stopTracking() {
        logger.info("🔄 Stopping app lifecycle tracking")
        updateAppActiveState(false)
        stopHeartbeat()
    }

    // MARK: - Private Methods

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }


    // MARK: - Heartbeat Management

    private func startHeartbeat() {
        stopHeartbeat() // Ensure no duplicate timers

        // Update heartbeat immediately
        updateHeartbeat()

        // Schedule timer for periodic updates
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: AppGroupConfig.heartbeatInterval, repeats: true) { [weak self] _ in
            self?.updateHeartbeat()
        }

        logger.info("💚 Heartbeat started (interval: \(AppGroupConfig.heartbeatInterval)s)")
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        // Write sentinel value to indicate app is not active
        sharedDefaults?.set(0.0, forKey: AppGroupConfig.heartbeatKey)
        sharedDefaults?.synchronize()

        logger.info("🛑 Heartbeat stopped")
    }

    @objc private func updateHeartbeat() {
        let timestamp = Date().timeIntervalSince1970
        sharedDefaults?.set(timestamp, forKey: AppGroupConfig.heartbeatKey)
        sharedDefaults?.synchronize()

        logger.info("💓 Heartbeat updated: \(timestamp)")
    }

    private func updateAppActiveState(_ isActive: Bool) {
        sharedDefaults?.set(isActive, forKey: AppGroupConfig.isMainAppActiveKey)
        sharedDefaults?.synchronize()

        logger.info("📱 App active state updated: \(isActive)")
    }

    // MARK: - Notification Handlers

    @objc private func appDidBecomeActive() {
        logger.info("📱 App did become active")
        startTracking()
    }

    @objc private func appWillResignActive() {
        logger.info("📱 App will resign active")
        // Don't stop tracking yet - app might still be in background
    }

    @objc private func appDidEnterBackground() {
        logger.info("📱 App did enter background")
        // Keep heartbeat running while in background (audio background mode allows this)
        // The heartbeat will continue as long as app has background execution time
    }

    @objc private func appWillEnterForeground() {
        logger.info("📱 App will enter foreground")
        // Ensure tracking is active
        startTracking()
    }

    @objc private func appWillTerminate() {
        logger.info("📱 App will terminate")
        stopTracking()
    }
}
