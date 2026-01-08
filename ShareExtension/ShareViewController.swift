//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Anton Novoselov on 2026.01.05
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import os

// MARK: - Share Extension View Model

@Observable
final class ShareExtensionViewModel {
    private var userDefaults: UserDefaults = UserDefaultsStorage.shared

    var availableModes: [VivaMode] = []
    var selectedMode: VivaMode = VivaMode.defaultMode {
        didSet {
            // Reset language to mode's default when mode changes
            selectedLanguage = selectedMode.transcriptionLanguage ?? "auto"
        }
    }
    var selectedLanguage: String = "auto"
    var isLoading = true
    var status = "Preparing audio..."
    var audioFileName: String?

    init() {
        loadModes()
        // Initialize language from selected mode
        selectedLanguage = selectedMode.transcriptionLanguage ?? "auto"
    }

    private func loadModes() {
        guard let savedModesData = userDefaults.data(forKey: AppGroupCoordinator.vivaModesKey),
              let savedModes = try? JSONDecoder().decode([VivaMode].self, from: savedModesData) else {
            availableModes = [VivaMode.defaultMode]
            return
        }

        availableModes = savedModes

        // Load previously selected mode
        let selectedModeName = userDefaults.string(forKey: AppGroupCoordinator.selectedVivaModeKey) ?? VivaMode.defaultMode.name
        selectedMode = availableModes.first(where: { $0.name == selectedModeName }) ?? VivaMode.defaultMode
    }

    func saveSelectedMode() {
        userDefaults.set(selectedMode.name, forKey: AppGroupCoordinator.selectedVivaModeKey)
        userDefaults.synchronize()
    }

    func saveLanguageOverride() {
        // Don't save override for models that auto-detect language
        guard isLanguageSelectionAvailable else {
            AppGroupCoordinator.shared.setPendingLanguageOverride(nil)
            return
        }

        // Only save if language differs from mode's default
        let modeLanguage = selectedMode.transcriptionLanguage ?? "auto"
        if selectedLanguage != modeLanguage {
            AppGroupCoordinator.shared.setPendingLanguageOverride(selectedLanguage)
        } else {
            AppGroupCoordinator.shared.setPendingLanguageOverride(nil)
        }
    }

    /// Whether language selection is available for the current model
    /// Returns false for Gemini and Parakeet V3 (they auto-detect)
    var isLanguageSelectionAvailable: Bool {
        let provider = selectedMode.transcriptionProvider
        let modelName = selectedMode.transcriptionModel

        // Gemini always auto-detects
        if provider == .gemini { return false }

        // Parakeet V3 auto-detects, V2 needs language param
        if provider == .parakeet {
            return modelName == "parakeet-tdt-0.6b-v2"
        }

        return true
    }

    /// Languages supported by the current transcription model
    var availableLanguages: [(code: String, name: String)] {
        guard isLanguageSelectionAvailable else { return [] }

        // Get the current model's supported languages
        let modelName = selectedMode.transcriptionModel
        let provider = selectedMode.transcriptionProvider

        // Find the model and get its supported languages
        let allModels: [any TranscriptionModel] =
            TranscriptionModelProvider.allParakeetModels +
            TranscriptionModelProvider.allWhisperKitModels +
            TranscriptionModelProvider.allCloudModels

        let supportedLanguages: [String: String]
        if let model = allModels.first(where: { $0.name == modelName && $0.provider == provider }) {
            supportedLanguages = model.supportedLanguages
        } else {
            supportedLanguages = TranscriptionModelProvider.allLanguages
        }

        // Sort languages: Auto first, then alphabetically by name
        return supportedLanguages
            .map { (code: $0.key, name: $0.value) }
            .sorted { lhs, rhs in
                if lhs.code == "auto" { return true }
                if rhs.code == "auto" { return false }
                return lhs.name < rhs.name
            }
    }

    
    var transcriptionModelDisplayName: String {
        let modelName = selectedMode.transcriptionModel
        if modelName.isEmpty {
            return "Not set"
        }
        return selectedMode.transcriptionProvider.getTranscriptionModelDisplayName(modelName)
    }

    var transcriptionLanguageDisplayName: String {
        let languageCode = selectedLanguage
        if languageCode == "auto" {
            return "🌐 Auto-detect"
        }
        let languageName = TranscriptionModelProvider.allLanguages[languageCode] ?? languageCode
        return TranscriptionModelProvider.languageWithFlag(languageCode, name: languageName)
    }

    var aiProviderDisplayName: String {
        guard let provider = selectedMode.aiProvider else {
            return "Not set"
        }
        return provider.displayName
    }

    var aiModelDisplayName: String {
        let model = selectedMode.aiModel
        return model.isEmpty ? "Not set" : model
    }

    var promptDisplayName: String {
        selectedMode.userPrompt?.title ?? "Not set"
    }
}

// MARK: - SwiftUI View

struct ShareExtensionView: View {
    @Bindable var viewModel: ShareExtensionViewModel
    var onTranscribe: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text("Transcribe Audio")
                        .font(.headline)

                    Spacer()

                    // Invisible spacer for centering
                    Text("Cancel")
                        .opacity(0)
                }
                .padding()

                Divider()

                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .frame(maxWidth: 400)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.orange)

            Text(viewModel.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private var contentView: some View {
        VStack(spacing: 16) {
            // Mode Picker
            modePickerSection

            Divider()

            // Transcription Info
            transcriptionInfoSection

            // AI Enhancement Info (only if enabled)
            if viewModel.selectedMode.aiEnhanceEnabled {
                Divider()
                aiEnhancementInfoSection
            }

            Divider()

            // Transcribe Button
            Button {
                viewModel.saveSelectedMode()
                viewModel.saveLanguageOverride()
                onTranscribe()
            } label: {
                Text("Transcribe")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }

    private var modePickerSection: some View {
        HStack {
            Text("Mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Picker("Mode", selection: $viewModel.selectedMode) {
                ForEach(viewModel.availableModes) { mode in
                    Text(mode.name).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .padding(.horizontal)
    }

    private var transcriptionInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            infoRow(label: "Provider", value: viewModel.selectedMode.transcriptionProvider.displayName)
            infoRow(label: "Model", value: viewModel.transcriptionModelDisplayName)
            languagePickerRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var languagePickerRow: some View {
        HStack {
            Text("Language")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            if viewModel.isLanguageSelectionAvailable {
                Picker("Language", selection: $viewModel.selectedLanguage) {
                    ForEach(viewModel.availableLanguages, id: \.code) { language in
                        Text(language.code == "auto" ? "🌐 Auto-detect" : TranscriptionModelProvider.languageWithFlag(language.code, name: language.name))
                            .tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            } else {
                Text("Autodetected by model")
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var aiEnhancementInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI Enhancement")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            infoRow(label: "Provider", value: viewModel.aiProviderDisplayName)
            infoRow(label: "Model", value: viewModel.aiModelDisplayName)
            infoRow(label: "Prompt", value: viewModel.promptDisplayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

// MARK: - View Controller

@MainActor
class ShareViewController: UIViewController {

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.ShareExtension", category: "ShareViewController")

    private let viewModel = ShareExtensionViewModel()
    private var hostingController: UIHostingController<ShareExtensionView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        Task {
            await processSharedAudio()
        }
    }

    private func setupUI() {
        let swiftUIView = ShareExtensionView(
            viewModel: viewModel,
            onTranscribe: { [weak self] in
                Task {
                    await self?.openMainApp()
                }
            },
            onCancel: { [weak self] in
                self?.cancelExtension(error: .cancelled)
            }
        )
        let hosting = UIHostingController(rootView: swiftUIView)
        hosting.view.backgroundColor = .clear

        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hosting.didMove(toParent: self)
        hostingController = hosting
    }

    private func processSharedAudio() async {
        guard let extensionContext = extensionContext else {
            logger.error("No extension context")
            cancelExtension(error: .noAudioFound)
            return
        }

        // Get all attachments from input items
        let attachments = extensionContext.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .compactMap(\.attachments)
            .flatMap { $0 }

        // Find attachment that can be loaded as URL (Info.plist already filters to audio types)
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            do {
                let url = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL

                guard let sourceURL = url else {
                    logger.error("No URL returned from provider")
                    continue
                }

                logger.info("Loaded audio file: \(sourceURL.lastPathComponent)")
                await copyAudioToSharedContainer(from: sourceURL)
                return

            } catch {
                logger.error("Failed to load item: \(error.localizedDescription)")
                continue
            }
        }

        logger.error("No audio attachment found")
        cancelExtension(error: .noAudioFound)
    }

    private func copyAudioToSharedContainer(from sourceURL: URL) async {
        // Get shared container directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupCoordinator.shared.appGroupId) else {
            cancelExtension(message: "Failed to get app group container URL")
            return
        }

        // Create SharedAudio directory
        let sharedAudioDir = containerURL.appendingPathComponent("SharedAudio")
        do {
            try FileManager.default.createDirectory(at: sharedAudioDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create SharedAudio directory: \(error.localizedDescription)")
        }

        // Generate unique filename preserving extension
        let fileExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = sharedAudioDir.appendingPathComponent(uniqueFileName)

        do {
            // Remove existing file if any
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy file to shared container
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            logger.info("Copied audio file to: \(destinationURL.lastPathComponent)")

            // Store the filename for later use when user taps Transcribe
            viewModel.audioFileName = uniqueFileName

            // Audio is ready - show mode selection UI
            viewModel.isLoading = false

        } catch {
            logger.error("Failed to copy audio file: \(error.localizedDescription)")
            cancelExtension(error: .genericError(NSError()))
        }
    }

    private func openMainApp() async {
        // Save the audio filename to shared UserDefaults before opening main app
        guard let audioFileName = viewModel.audioFileName,
              let sharedDefaults = UserDefaults(suiteName: AppGroupCoordinator.shared.appGroupId) else {
            logger.error("No audio filename or shared defaults")
            cancelExtension(error: .genericError(NSError()))
            return
        }

        sharedDefaults.set(audioFileName, forKey: AppGroupCoordinator.kPendingSharedAudioFileName)
        sharedDefaults.synchronize()
        logger.info("Saved pending audio filename to UserDefaults: \(audioFileName)")

        // Update UI to show opening state
        viewModel.status = "Opening VivaDicta..."
        viewModel.isLoading = true

        // Use URL scheme to open main app
        guard let url = URL(string: "vivadicta://transcribe-shared") else {
            logger.error("Failed to create URL for main app")
            cancelExtension(error: .genericError(NSError()))
            return
        }

        // Open URL via responder chain traversal.
        // App Extensions cannot directly access UIApplication.shared (it's unavailable in extension targets).
        // Instead, we traverse the responder chain to find the UIApplication instance,
        // which allows us to call open(_:) to launch the main app via its URL scheme.
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                let success = await application.open(url)
                logger.info("Opened main app: \(success)")
                finishExtension()
                return
            }
            responder = responder?.next
        }

        // Fallback: complete after a short delay
        try? await Task.sleep(for: .milliseconds(500))
        finishExtension()
    }

    private func finishExtension() {
        extensionContext?.completeRequest(returningItems: [])
    }

    private func cancelExtension(error: VivaDictaExtensionError) {
        extensionContext?.cancelRequest(withError: error)
    }

    private func cancelExtension(message: String) {
        let error = NSError(
            domain: "com.antonnovoselov.VivaDicta.ShareExtension",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }
}

enum VivaDictaExtensionError: Error {
    case noAudioFound
    case genericError(NSError)
    case cancelled
}
