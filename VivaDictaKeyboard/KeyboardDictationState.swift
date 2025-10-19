import SwiftUI

extension Notification.Name {
    static let didFinalizeTranscription = Notification.Name("didFinalizeTranscription")
}

@Observable
final class KeyboardDictationState {
    // MARK: - Published state
    var isRecording: Bool
    var isSessionActive: Bool
    var transcriptionStatus: AppGroupCoordinator.TranscriptionStatus
    var isPaused: Bool = false
    var errorMessage: String? {
        didSet {
            if errorMessage == nil && transcriptionStatus == .error {
                AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
            }
            if errorMessage != nil && transcriptionStatus == .error {
                autoDismissError()
            }
        }
    }

    // MARK: - FlowMode Manager
    let flowModeManager = FlowModeManager()

    // MARK: - Auto-dismiss timer
    private var errorDismissTimer: Timer?

    // MARK: - Init
    init() {
        self.isRecording = AppGroupCoordinator.shared.isRecording
        self.isSessionActive = AppGroupCoordinator.shared.isKeyboardSessionActive
        self.transcriptionStatus = AppGroupCoordinator.shared.transcriptionStatus
//        self.isPaused = AppGroupCoordinator.shared.isPaused
    }

    // MARK: - UI Derivations
    enum UIState { case notReady, ready, recording, processing, error }

    var uiState: UIState {
        if isRecording { return .recording }
        switch transcriptionStatus {
        case .transcribing, .enhancing: return .processing
        case .error: return .error
        default: break
        }
        return isSessionActive ? .ready : .notReady
    }

    var micColor: Color {
        switch uiState {
        case .notReady: return .secondary
        case .ready: return .green
        case .recording: return .red
        case .processing: return .primary
        case .error: return .orange
        }
    }

    // MARK: - Lifecycle
    func start() {
        // Refresh FlowModes when keyboard starts
        flowModeManager.refreshFlowModes()

        AppGroupCoordinator.shared.onRecordingStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.isRecording = state }
        }
        AppGroupCoordinator.shared.onPausedStateChanged = { [weak self] paused in
            DispatchQueue.main.async { self?.isPaused = paused }
        }
        AppGroupCoordinator.shared.onKeyboardSessionActivated = { [weak self] in
            DispatchQueue.main.async { self?.isSessionActive = true }
        }
        AppGroupCoordinator.shared.onKeyboardSessionExpired = { [weak self] in
            DispatchQueue.main.async { self?.isSessionActive = false }
        }
        AppGroupCoordinator.shared.onTranscriptionTranscribing = { [weak self] in
            DispatchQueue.main.async { self?.transcriptionStatus = .transcribing }
        }
        AppGroupCoordinator.shared.onTranscriptionEnhancing = { [weak self] in
            DispatchQueue.main.async { self?.transcriptionStatus = .enhancing }
        }
        AppGroupCoordinator.shared.onTranscriptionCompleted = { [weak self] transcription in
            DispatchQueue.main.async {
                self?.transcriptionStatus = .completed
                NotificationCenter.default.post(
                    name: .didFinalizeTranscription,
                    object: nil,
                    userInfo: ["text": transcription]
                )
            }
        }
        AppGroupCoordinator.shared.onTranscriptionError = { [weak self] in
            DispatchQueue.main.async { self?.transcriptionStatus = .error }
        }
        AppGroupCoordinator.shared.onTranscriptionErrorMessage = { [weak self] message in
            DispatchQueue.main.async { self?.errorMessage = message }
        }
    }

    func stop() {
        AppGroupCoordinator.shared.onRecordingStateChanged = nil
        AppGroupCoordinator.shared.onKeyboardSessionActivated = nil
        AppGroupCoordinator.shared.onKeyboardSessionExpired = nil
        AppGroupCoordinator.shared.onTranscriptionTranscribing = nil
        AppGroupCoordinator.shared.onTranscriptionEnhancing = nil
        AppGroupCoordinator.shared.onTranscriptionCompleted = nil
        AppGroupCoordinator.shared.onTranscriptionError = nil
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
    }

    // MARK: - Actions
    func requestStartRecording() {
        if transcriptionStatus == .error {
            errorMessage = nil
            transcriptionStatus = .idle
            AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
        }

        if AppGroupCoordinator.shared.isKeyboardSessionActive {
            AppGroupCoordinator.shared.requestStartRecording()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if !self.isRecording {
                    self.isSessionActive = false
                }
            }
        } else {
            self.isSessionActive = false
        }
    }
    func requestStopRecording() { AppGroupCoordinator.shared.requestStopRecording() }
    func requestCancelRecording() { AppGroupCoordinator.shared.requestCancelRecording() }
//    func requestPauseRecording() { AppGroupCoordinator.shared.requestPauseRecording() }
//    func requestResumeRecording() { AppGroupCoordinator.shared.requestResumeRecording() }

    // MARK: - Error Auto-dismiss
    private func autoDismissError() {
        errorDismissTimer?.invalidate()
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.transcriptionStatus == .error && self.errorMessage != nil {
                    self.clearError()
                }
            }
        }
    }

    private func clearError() {
        errorMessage = nil
        transcriptionStatus = .idle
        AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil
    }
}
