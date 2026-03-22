import SwiftUI


@Observable
final class KeyboardDictationState {
    // MARK: - Published state
    var isRecording: Bool
    var isSessionActive: Bool
    var transcriptionStatus: AppGroupCoordinator.TranscriptionStatus
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

    // Audio level from main app recording (0.0 to 1.0)
    var currentAudioLevel: CGFloat = 0.0

    // MARK: - Keyboard Tab

    /// The active keyboard tab: `.keyboard` for normal typing, `.textProcessing` for rewrite mode.
    enum KeyboardTab: Int {
        case keyboard = 0
        case textProcessing = 1
    }

    var activeTab: KeyboardTab = .keyboard {
        didSet {
            UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)?
                .set(activeTab.rawValue, forKey: "keyboardActiveTab")
        }
    }

    // MARK: - Text Processing (Rewrite)

    enum TextProcessingPhase: Equatable {
        case idle
        case sendingToApp
        case waitingForResult(modeName: String)
        case completed
        case error(String)
    }

    var textProcessingPhase: TextProcessingPhase = .idle

    /// Callback for when the main app returns a processed text result.
    var onTextProcessingResult: ((String) -> Void)?

    /// Callback for when the main app returns a text processing error.
    var onTextProcessingError: ((String) -> Void)?

    /// Callback for when the keyboard session expires during text processing.
    var onSessionExpired: (() -> Void)?

    // MARK: - VivaMode Manager
    var vivaModeManager = VivaModeManager()

    // Callback called when transcription text is ready to be pasted to user's input field. Called by KeyboardViewController
    var onTranscriptionReady: ((String) -> Void)?

    // MARK: - Auto-dismiss timer
    private var errorDismissTimer: Timer?

    // MARK: - Init
    init() {
        self.isRecording = AppGroupCoordinator.shared.isRecording
        self.isSessionActive = AppGroupCoordinator.shared.isKeyboardSessionActive
        self.transcriptionStatus = AppGroupCoordinator.shared.transcriptionStatus

        // Restore last active tab
        let savedTab = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId)?
            .integer(forKey: "keyboardActiveTab") ?? 0
        self.activeTab = KeyboardTab(rawValue: savedTab) ?? .keyboard
    }

    // MARK: - UI Derivations
    enum UIState {
        case notReady,
             ready,
             recording,
             processing,
             error
    }

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
        case .ready: return .orange
        case .recording: return .red
        case .processing: return .primary
        case .error: return .orange
        }
    }

    // MARK: - Lifecycle
    func start() {
        // Refresh VivaModes when keyboard starts
        vivaModeManager.refreshVivaModes()

        // TODO: Refactor to Task all below
        AppGroupCoordinator.shared.onRecordingStateChanged = { [weak self] state in
            DispatchQueue.main.async { self?.isRecording = state }
        }
        AppGroupCoordinator.shared.onKeyboardSessionActivated = { [weak self] in
            DispatchQueue.main.async { self?.isSessionActive = true }
        }
        AppGroupCoordinator.shared.onKeyboardSessionExpired = { [weak self] in
            DispatchQueue.main.async {
                self?.isSessionActive = false
                self?.onSessionExpired?()
            }
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
                self?.onTranscriptionReady?(transcription)
            }
        }
        AppGroupCoordinator.shared.onTranscriptionError = { [weak self] in
            DispatchQueue.main.async { self?.transcriptionStatus = .error }
        }
        AppGroupCoordinator.shared.onTranscriptionCancelled = { [weak self] in
            DispatchQueue.main.async { self?.transcriptionStatus = .idle }
        }
        AppGroupCoordinator.shared.onTranscriptionErrorMessage = { [weak self] message in
            DispatchQueue.main.async { self?.errorMessage = message }
        }
        AppGroupCoordinator.shared.onAudioLevelUpdated = { [weak self] level in
            DispatchQueue.main.async { self?.currentAudioLevel = level }
        }

        // Text processing callbacks (rewrite feature)
        AppGroupCoordinator.shared.onTextProcessingCompleted = { [weak self] text in
            DispatchQueue.main.async { self?.onTextProcessingResult?(text) }
        }
        AppGroupCoordinator.shared.onTextProcessingError = { [weak self] message in
            DispatchQueue.main.async { self?.onTextProcessingError?(message) }
        }
    }
    
    nonisolated func stop() {
        // Clear all callbacks - these are @MainActor isolated but setting to nil is safe
        Task { @MainActor in
            AppGroupCoordinator.shared.onRecordingStateChanged = nil
            AppGroupCoordinator.shared.onKeyboardSessionActivated = nil
            AppGroupCoordinator.shared.onKeyboardSessionExpired = nil
            AppGroupCoordinator.shared.onTranscriptionTranscribing = nil
            AppGroupCoordinator.shared.onTranscriptionEnhancing = nil
            AppGroupCoordinator.shared.onTranscriptionCompleted = nil
            AppGroupCoordinator.shared.onTranscriptionError = nil
            AppGroupCoordinator.shared.onTranscriptionCancelled = nil
            AppGroupCoordinator.shared.onAudioLevelUpdated = nil
            AppGroupCoordinator.shared.onTextProcessingCompleted = nil
            AppGroupCoordinator.shared.onTextProcessingError = nil
            errorDismissTimer?.invalidate()
            errorDismissTimer = nil
        }
    }

    // MARK: - Actions
    func requestStartRecording() {
        if transcriptionStatus == .error {
            errorMessage = nil
            transcriptionStatus = .idle
            AppGroupCoordinator.shared.updateTranscriptionStatus(.idle)
        }

        if AppGroupCoordinator.shared.isKeyboardSessionActive {
            if vivaModeManager.selectedVivaMode.useClipboardContext {
                // Capture clipboard from keyboard context for AI processing
                // (keyboard has direct access to the active app's clipboard)
                AppGroupCoordinator.shared.setKeyboardClipboardContext(UIPasteboard.general.string)
            }
            AppGroupCoordinator.shared.requestStartRecording()
            
            // TODO: why delay? Refactor to Task
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
    
    func requestStopRecording() {
        AppGroupCoordinator.shared.requestStopRecording()
    }
    
    func requestCancelRecording() {
        AppGroupCoordinator.shared.requestCancelRecording()
    }

    // MARK: - Error Auto-dismiss
    private func autoDismissError() {
        errorDismissTimer?.invalidate()
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            // TODO: Refactor to Task
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
