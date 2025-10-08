//
//  AppStateMonitoringService.swift
//  VivaDictaKeyboard
//
//  Service responsible for monitoring main app and recording states
//

import Foundation
import os

/// Delegate protocol for app state monitoring events
public protocol AppStateMonitoringDelegate: AnyObject {
    func appStateDidChange(isActive: Bool)
    func recordingStateDidChange(isRecording: Bool)
}

/// Protocol for app state monitoring service to enable mocking in tests
public protocol AppStateMonitoring: AnyObject {
    var delegate: AppStateMonitoringDelegate? { get set }
    var isMainAppActive: Bool { get }
    var isRecording: Bool { get }

    func startMonitoring()
    func stopMonitoring()
    func updateStates()
}

/// Service that monitors app and recording states periodically
public class AppStateMonitoringService: AppStateMonitoring {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AppStateMonitoring")
    private let appStateDetector: AppStateDetector
    private let recordingStateDetector: RecordingStateDetector
    private var monitoringTimer: Timer?

    public weak var delegate: AppStateMonitoringDelegate?

    // Current state cache
    public private(set) var isMainAppActive: Bool = false
    public private(set) var isRecording: Bool = false

    // MARK: - Initialization

    public init(
        appStateDetector: AppStateDetector = AppStateDetector(),
        recordingStateDetector: RecordingStateDetector = RecordingStateDetector()
    ) {
        self.appStateDetector = appStateDetector
        self.recordingStateDetector = recordingStateDetector
    }

    // MARK: - Public Methods

    /// Start monitoring app and recording states
    public func startMonitoring() {
        // Stop any existing timer
        stopMonitoring()

        // Check state immediately
        updateStates()

        // Set up periodic monitoring (every 5 seconds matches heartbeat interval)
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.updateStates()
            }
        }

        logger.info("🔍 Started app state monitoring")
    }

    /// Stop monitoring app and recording states
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        logger.info("🔍 Stopped app state monitoring")
    }

    /// Force an immediate state update (useful for manual refresh)
    public func updateStates() {
        let previousAppState = isMainAppActive
        let newAppState = appStateDetector.isMainAppActive()

        let previousRecordingState = isRecording
        let newRecordingState = recordingStateDetector.isRecordingActive()

        // Update cached states
        isMainAppActive = newAppState
        isRecording = newRecordingState

        // Notify delegate of changes
        if previousAppState != newAppState {
            logger.info("📱 App state changed: \(newAppState ? "ACTIVE ✅" : "SUSPENDED ⏸️")")
            delegate?.appStateDidChange(isActive: newAppState)
        }

        if previousRecordingState != newRecordingState {
            logger.info("🎤 Recording state changed: \(newRecordingState ? "RECORDING 🔴" : "NOT RECORDING ⏹️")")

            // Log heartbeat age for debugging
            if let age = recordingStateDetector.recordingHeartbeatAge() {
                logger.info("🎤 💙 Recording heartbeat age: \(String(format: "%.1f", age))s")
            }

            delegate?.recordingStateDidChange(isRecording: newRecordingState)
        }
    }
}
