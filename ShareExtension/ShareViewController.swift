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
    private let appGroupId = "group.com.antonnovoselov.VivaDicta"
    private var userDefaults: UserDefaults = UserDefaultsStorage.shared

    var availableModes: [VivaMode] = []
    var selectedMode: VivaMode = VivaMode.defaultMode
    var isLoading = true
    var status = "Preparing audio..."
    var audioFileName: String?

    init() {
        loadModes()
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

    // MARK: - Display Helpers

    var transcriptionProviderDisplayName: String {
        switch selectedMode.transcriptionProvider {
        case .whisperKit:
            return "WhisperKit"
        case .parakeet:
            return "Parakeet"
        case .openAI:
            return "OpenAI"
        case .groq:
            return "Groq"
        case .elevenLabs:
            return "ElevenLabs"
        case .deepgram:
            return "Deepgram"
        case .mistral:
            return "Mistral"
        case .gemini:
            return "Gemini"
        case .soniox:
            return "Soniox"
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
        guard let languageCode = selectedMode.transcriptionLanguage else {
            return "Auto-detect"
        }
        return TranscriptionModelProvider.allLanguages[languageCode] ?? languageCode
    }

    var aiProviderDisplayName: String {
        guard let provider = selectedMode.aiProvider else {
            return "Not set"
        }
        return provider.rawValue.capitalized
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

            infoRow(label: "Provider", value: viewModel.transcriptionProviderDisplayName)
            infoRow(label: "Model", value: viewModel.transcriptionModelDisplayName)
            infoRow(label: "Language", value: viewModel.transcriptionLanguageDisplayName)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
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

    private let appGroupId = "group.com.antonnovoselov.VivaDicta"
    private let pendingAudioFileNameKey = "pendingSharedAudioFileName"

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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
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
              let sharedDefaults = UserDefaults(suiteName: appGroupId) else {
            logger.error("No audio filename or shared defaults")
            cancelExtension(error: .genericError(NSError()))
            return
        }

        sharedDefaults.set(audioFileName, forKey: pendingAudioFileNameKey)
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

        // Open URL via responder chain
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
        let error = NSError(domain: "com.antonnovoselov.VivaDicta.ShareExtension", code: -1)
        extensionContext?.cancelRequest(withError: error)
    }
}

enum VivaDictaExtensionError: Error {
    case noAudioFound
    case genericError(NSError)
    case cancelled
}
