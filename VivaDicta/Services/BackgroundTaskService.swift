//
//  BackgroundTaskService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.04
//

import UIKit
import BackgroundTasks
import SwiftData
import os

/// Manages background task protection for transcription and AI processing.
///
/// Provides two mechanisms:
/// 1. `UIApplication.beginBackgroundTask` for immediate background time (~30s)
/// 2. `BGProcessingTask` via `BGTaskScheduler` for longer deferred processing
///
/// The primary use case is protecting Watch audio processing, which happens
/// entirely in background when the iPhone receives files via WatchConnectivity.
@MainActor
final class BackgroundTaskService {
    nonisolated static let bgTaskIdentifier = "com.antonnovoselov.VivaDicta.transcription-processing"

    /// Live instance reference for the BGTask handler to dispatch to.
    static nonisolated(unsafe) weak var shared: BackgroundTaskService?

    private let logger = Logger(category: .backgroundTask)
    private nonisolated(unsafe) let queue: BackgroundTaskQueue
    private let modelContainer: ModelContainer
    private var watchAudioProcessor: WatchAudioProcessor?
    private var isProcessingQueue = false
    private var bgProcessingDrainTask: Task<Void, Never>?

    init(modelContainer: ModelContainer) {
        self.queue = BackgroundTaskQueue()
        self.modelContainer = modelContainer
        Self.shared = self
    }

    func configure(watchAudioProcessor: WatchAudioProcessor) {
        self.watchAudioProcessor = watchAudioProcessor
    }

    // MARK: - UIApplication Background Task

    /// Begins a UIKit background task and returns its identifier.
    ///
    /// Each caller gets its own background task ID, supporting concurrent
    /// Watch file processing. The expiration handler ends the task automatically;
    /// `endBackgroundTask` is safe to call afterward (it checks for double-end).
    func beginBackgroundTask(
        name: String,
        onExpiration: @escaping @Sendable () -> Void
    ) -> UIBackgroundTaskIdentifier {
        let lock = NSLock()
        var taskID: UIBackgroundTaskIdentifier = .invalid
        var ended = false
        taskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            onExpiration()
            // iOS expects the task to be ended inside the expiration handler
            lock.lock()
            if !ended {
                ended = true
                UIApplication.shared.endBackgroundTask(taskID)
                lock.unlock()
                self?.logger.logInfo("Background task ended by expiration (id: \(taskID.rawValue))")
            } else {
                lock.unlock()
            }
        }
        if taskID == .invalid {
            logger.logWarning("Failed to begin background task: \(name)")
        } else {
            logger.logInfo("Began background task: \(name) (id: \(taskID.rawValue))")
            // Store the lock+ended flag for endBackgroundTask to use
            backgroundTaskLocks[taskID] = (lock, { ended }, { ended = true })
        }
        return taskID
    }

    /// Tracks lock and ended state for each active background task to prevent double-end.
    private var backgroundTaskLocks: [UIBackgroundTaskIdentifier: (NSLock, () -> Bool, () -> Void)] = [:]

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        guard identifier != .invalid else { return }
        if let (lock, isEnded, markEnded) = backgroundTaskLocks[identifier] {
            lock.lock()
            if !isEnded() {
                markEnded()
                UIApplication.shared.endBackgroundTask(identifier)
                lock.unlock()
                logger.logInfo("Ended background task (id: \(identifier.rawValue))")
            } else {
                lock.unlock()
                logger.logInfo("Background task already ended (id: \(identifier.rawValue))")
            }
            backgroundTaskLocks.removeValue(forKey: identifier)
        } else {
            UIApplication.shared.endBackgroundTask(identifier)
            logger.logInfo("Ended background task (id: \(identifier.rawValue))")
        }
    }

    // MARK: - BGProcessingTask

    /// Registers the BGProcessingTask handler. Must be called during `didFinishLaunching`.
    ///
    /// The handler dispatches to the live `shared` instance. By the time iOS delivers
    /// a BGProcessingTask, AppState (and thus BackgroundTaskService) is always initialized
    /// because the task is scheduled from within the running app.
    static func registerBGTaskHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            guard let bgTask = task as? BGProcessingTask else { return }
            Task { @MainActor in
                guard let service = shared else {
                    bgTask.setTaskCompleted(success: false)
                    return
                }
                service.handleBGProcessingTask(bgTask)
            }
        }
    }

    private var bgTaskExpired = false

    private func handleBGProcessingTask(_ task: BGProcessingTask) {
        logger.logInfo("Handling BGProcessingTask")
        bgTaskExpired = false

        bgProcessingDrainTask = Task {
            await processQueue()
            guard !bgTaskExpired else { return } // Expiration handler already completed the task
            scheduleIfNeeded()
            task.setTaskCompleted(success: queue.isEmpty)
            logger.logInfo("BGProcessingTask completed, queue empty: \(queue.isEmpty)")
        }

        task.expirationHandler = { [weak self] in
            self?.bgTaskExpired = true
            self?.bgProcessingDrainTask?.cancel()
            self?.scheduleIfNeeded()
            task.setTaskCompleted(success: false)
        }
    }

    /// Schedules a BGProcessingTask. Thread-safe - can be called from expiration handlers.
    nonisolated func scheduleBGProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: Self.bgTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            let logger = Logger(category: .backgroundTask)
            logger.logError("Failed to schedule BGProcessingTask: \(error.localizedDescription)")
        }
    }

    /// Schedules a BGProcessingTask if the queue has pending items. Thread-safe.
    nonisolated func scheduleIfNeeded() {
        guard !queue.isEmpty else { return }
        scheduleBGProcessingTask()
    }

    // MARK: - Queue Management

    /// Enqueues a work item for later processing. Thread-safe - can be called from
    /// expiration handlers without a MainActor hop.
    nonisolated func enqueueForLaterProcessing(audioURL: URL, sourceTag: String, modeId: String?, recordingTimestamp: Date = Date()) {
        let item = BackgroundWorkItem(
            audioFileURL: audioURL,
            sourceTag: sourceTag,
            modeId: modeId,
            recordingTimestamp: recordingTimestamp
        )
        queue.enqueue(item)
        scheduleBGProcessingTask()
    }

    /// Returns filenames currently in the queue (for orphan recovery exclusion).
    func queuedFileNames() -> Set<String> {
        queue.queuedFileNames()
    }

    /// Removes a queued item if the audio file was successfully processed.
    /// Cancels the pending BGProcessingTask if the queue is now empty.
    func removeFromQueueIfProcessed(audioFileName: String) {
        if transcriptionExists(for: audioFileName) {
            queue.removeByFileName(audioFileName)
            if queue.isEmpty {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskIdentifier)
                logger.logInfo("Queue empty after success, cancelled pending BGProcessingTask")
            }
        }
    }

    func processQueue() async {
        guard !isProcessingQueue else { return }
        guard let watchAudioProcessor else {
            logger.logError("WatchAudioProcessor not configured, cannot process queue")
            return
        }
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        for item in queue.allPending() {
            // Stop if cancelled (e.g. BGProcessingTask expired)
            guard !Task.isCancelled else {
                logger.logInfo("Queue processing cancelled")
                break
            }

            let fileName = item.audioFileURL.lastPathComponent

            // Skip if audio file no longer exists
            guard FileManager.default.fileExists(atPath: item.audioFileURL.path) else {
                logger.logWarning("Queued audio file missing, removing: \(fileName)")
                queue.remove(id: item.id)
                continue
            }

            // Skip if a Transcription already exists for this file (prevents duplicates)
            if transcriptionExists(for: fileName) {
                logger.logInfo("Transcription already exists for \(fileName), removing from queue")
                queue.remove(id: item.id)
                continue
            }

            // Skip if the file is currently being processed by a live Watch transfer
            if watchAudioProcessor.inFlightFiles.contains(fileName) {
                logger.logInfo("File in-flight, skipping: \(fileName)")
                continue
            }

            logger.logInfo("Processing queued item: \(fileName)")
            await watchAudioProcessor.processAudioFile(
                at: item.audioFileURL,
                sourceTag: item.sourceTag,
                recordingTimestamp: item.recordingTimestamp,
                modeId: item.modeId
            )

            // Check if processing actually created a Transcription
            if transcriptionExists(for: fileName) {
                queue.remove(id: item.id)
            } else {
                logger.logWarning("Processing did not create Transcription for \(fileName), marking failed")
                queue.markFailed(id: item.id)
            }
        }
    }

    /// Checks if a Transcription record already exists for the given audio filename.
    private func transcriptionExists(for audioFileName: String) -> Bool {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<Transcription>(
            predicate: #Predicate { $0.audioFileName == audioFileName }
        )
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }
}
