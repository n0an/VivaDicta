import Foundation
import AVFoundation
import UIKit

@Observable
final class AudioSessionManager {
    static let shared = AudioSessionManager()

    var isSessionActive: Bool = false
    var timeoutRemaining: TimeInterval = 0

    var onSessionTimeout: (() -> Void)?

    private var deactivationTimer: Timer?
//    private let settings = AppSettings.shared
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var engine = AVAudioEngine()
    private var pendingRebuildAfterRecording: Bool = false
//    private let liveActivityManager = LiveActivityManager.shared

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )

        Task {
            await AppGroupCoordinator.shared.onStopHotMicFromWidget = { [weak self] in
                Task { @MainActor in
                    self?.stopHotMicSession()
                }
            }
        }
    }

    func startHotMicSession(timeoutSeconds: Int) throws {
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )

        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        isSessionActive = true

        startBackgroundTask()

        engine.inputNode.removeTap(onBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { _, _ in }

        engine.prepare()
        try engine.start()
        engine.inputNode.removeTap(onBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { _, _ in }

        scheduleDeactivation(timeout: TimeInterval(timeoutSeconds))

        let sessionId = UUID().uuidString
        // TODO: Start live activity here
//        liveActivityManager.startHotMicActivity(sessionId: sessionId)
    }

    func pauseHotMicForRecording() {
        engine.inputNode.removeTap(onBus: 0)
    }

    func pauseDeactivationTimer() {
        cancelScheduledDeactivation()
        endBackgroundTask()
    }

    func resumeHotMicAfterRecording() {
        guard isSessionActive else { return }

        if pendingRebuildAfterRecording {
            pendingRebuildAfterRecording = false
            rebuildTapAndRestartEngine()
            return
        }

        do {
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            engine.inputNode.removeTap(onBus: 0)
            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { _, _ in }
        } catch {
            // Failed to reinstall hot mic tap
        }
    }

    func resumeDeactivationTimer() {
        // TODO: Get timeout session from settings
        let timeout = TimeInterval(180)
        startBackgroundTask()
        resumeHotMicAfterRecording()
        scheduleDeactivation(timeout: timeout)
    }

    func stopHotMicSession() {
        cancelScheduledDeactivation()

        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        if isSessionActive {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                isSessionActive = false
            } catch {
                // Failed to deactivate audio session
            }
        }

        endBackgroundTask()

        // TODO: Handle live activity
//        liveActivityManager.stopHotMicActivity()

        Task {
            await AppGroupCoordinator.shared.deactivateKeyboardSession()
        }
    }

    private func scheduleDeactivation(timeout: TimeInterval) {
        cancelScheduledDeactivation()

        guard timeout > 0 else {
            stopHotMicSession()
            return
        }

        timeoutRemaining = timeout

        deactivationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else {
                    return
                }

                self.timeoutRemaining -= 1

                if self.timeoutRemaining <= 0 {
                    self.stopHotMicSession()
                    self.onSessionTimeout?()
                }
            }
        }
    }

    private func cancelScheduledDeactivation() {

        deactivationTimer?.invalidate()
        deactivationTimer = nil
        timeoutRemaining = 0
    }

    private func startBackgroundTask() {
        endBackgroundTask()
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "VivaDicta Hot Mic Session") { [weak self] in
            Task { @MainActor in
                self?.stopHotMicSession()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard isSessionActive else { return }
        let reasonValue = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
        guard let reason = reasonValue.flatMap({ AVAudioSession.RouteChangeReason(rawValue: $0) }) else { return }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .categoryChange, .override, .routeConfigurationChange:
            Task {
                if await AppGroupCoordinator.shared.isRecording {
                    await MainActor.run {
                        pendingRebuildAfterRecording = true
                    }
                } else {
                    await MainActor.run {
                        rebuildTapAndRestartEngine()
                    }
                }
            }
        default:
            break
        }
    }

    private func rebuildTapAndRestartEngine() {
        do {
            if engine.isRunning { engine.stop() }
            engine = AVAudioEngine()

            engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { _, _ in }
            engine.prepare()
            try engine.start()
        } catch {
            isSessionActive = false
            endBackgroundTask()
            Task {
                await AppGroupCoordinator.shared.deactivateKeyboardSession()
            }
        }
    }
}
