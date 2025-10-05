//
//  RecordingCoordinator.swift
//  VivaDictaKeyboard
//
//  Service responsible for coordinating recording lifecycle and handling timeouts
//

import Foundation
import os

/// Delegate protocol for recording coordinator events
@MainActor
public protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingCoordinatorDidStartRecording()
    func recordingCoordinatorDidStopRecording()
    func recordingCoordinatorDidCancelRecording()
    func recordingCoordinatorDidTimeout()
}

/// Protocol for recording coordinator to enable mocking in tests
@MainActor
public protocol RecordingCoordination: AnyObject {
    var delegate: RecordingCoordinatorDelegate? { get set }

    func startRecording()
    func stopRecording()
    func cancelRecording()
    func cancelRecordingTimeout()
}

/// Service that coordinates recording operations and handles timeouts
@MainActor
public class RecordingCoordinator: RecordingCoordination {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "RecordingCoordinator")
    private let appGroupCoordinator: AppGroupCoordinator
    private var recordingTimeoutTask: Task<Void, Never>?

    public weak var delegate: RecordingCoordinatorDelegate?

    // MARK: - Initialization

    public init(appGroupCoordinator: AppGroupCoordinator = .shared) {
        self.appGroupCoordinator = appGroupCoordinator
    }

    // MARK: - Public Methods

    /// Start recording
    public func startRecording() {
        logger.info("🎤 Starting recording via Darwin notification")
        appGroupCoordinator.requestStartRecording()

        // Set up timeout in case recording doesn't start
        startRecordingTimeout()

        // Notify delegate
        delegate?.recordingCoordinatorDidStartRecording()
    }

    /// Stop recording (with transcription)
    public func stopRecording() {
        logger.info("🎤 Stopping recording via Darwin notification")
        appGroupCoordinator.requestStopRecording()

        // Cancel any pending timeout
        cancelRecordingTimeout()

        // Notify delegate
        delegate?.recordingCoordinatorDidStopRecording()
    }

    /// Cancel recording (without transcription)
    public func cancelRecording() {
        logger.info("🎤 Canceling recording via Darwin notification")
        appGroupCoordinator.requestCancelRecording()

        // Cancel any pending timeout
        cancelRecordingTimeout()

        // Notify delegate
        delegate?.recordingCoordinatorDidCancelRecording()
    }

    /// Cancel any pending timeout task
    public func cancelRecordingTimeout() {
        recordingTimeoutTask?.cancel()
        recordingTimeoutTask = nil
    }

    // MARK: - Private Methods

    private func startRecordingTimeout() {
        // Cancel any existing timeout
        cancelRecordingTimeout()

        // Start new timeout
        recordingTimeoutTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(AppGroupConfig.recordingStartTimeout * 1_000_000_000))

                // If we reach here, timeout occurred
                logger.info("⏰ Recording timeout - recording didn't start within \(AppGroupConfig.recordingStartTimeout) seconds")

                // Notify delegate
                delegate?.recordingCoordinatorDidTimeout()

            } catch {
                // Task was cancelled, this is normal
            }
        }
    }
}
