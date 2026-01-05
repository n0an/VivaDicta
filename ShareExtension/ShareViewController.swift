//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Anton Novoselov on 05.01.2026.
//

import UIKit
import UniformTypeIdentifiers
import os

@MainActor
class ShareViewController: UIViewController {

    private let appGroupId = "group.com.antonnovoselov.VivaDicta"
    private let pendingAudioFileNameKey = "pendingSharedAudioFileName"

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta.ShareExtension", category: "ShareViewController")

    private lazy var loadingView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 16
        return view
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .systemOrange
        return indicator
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Preparing audio..."
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        Task {
            await processSharedAudio()
        }
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        view.addSubview(loadingView)
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 200),
            loadingView.heightAnchor.constraint(equalToConstant: 120),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loadingView.topAnchor, constant: 24),

            statusLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -8)
        ])

        activityIndicator.startAnimating()
    }

    private func processSharedAudio() async {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            logger.error("No extension context or input items")
            await completeWithError(message: "No audio file found")
            return
        }

        // Find audio attachment
        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Check for various audio UTIs
                let audioTypes: [UTType] = [
                    .audio,
                    .mpeg4Audio,
                    .wav,
                    .mp3,
                    .aiff
                ]

                for audioType in audioTypes {
                    if provider.hasItemConformingToTypeIdentifier(audioType.identifier) {
                        logger.info("Found audio attachment with type: \(audioType.identifier)")
                        await loadAudioFile(from: provider, contentType: audioType)
                        return
                    }
                }

                // Also check for generic public.audio
                if provider.hasItemConformingToTypeIdentifier("public.audio") {
                    logger.info("Found generic audio attachment")
                    await loadAudioFile(from: provider, contentType: .audio)
                    return
                }
            }
        }

        logger.error("No audio attachment found in shared items")
        await completeWithError(message: "No audio file found")
    }

    private func loadAudioFile(from provider: NSItemProvider, contentType: UTType) async {
        do {
            let url = try await provider.loadItem(forTypeIdentifier: contentType.identifier) as? URL

            guard let sourceURL = url else {
                logger.error("No URL returned from provider")
                await completeWithError(message: "Failed to access audio")
                return
            }

            logger.info("Loaded audio file from: \(sourceURL.lastPathComponent)")
            await copyAndShareAudio(from: sourceURL)

        } catch {
            logger.error("Failed to load audio file: \(error.localizedDescription)")
            await completeWithError(message: "Failed to load audio")
        }
    }

    private func copyAndShareAudio(from sourceURL: URL) async {
        // Get shared container directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            logger.error("Failed to get app group container URL")
            await completeWithError(message: "Storage error")
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

            // Save filename to shared UserDefaults
            if let sharedDefaults = UserDefaults(suiteName: appGroupId) {
                sharedDefaults.set(uniqueFileName, forKey: pendingAudioFileNameKey)
                sharedDefaults.synchronize()
                logger.info("Saved pending audio filename to UserDefaults")
            }

            // Open main app
            await openMainApp()

        } catch {
            logger.error("Failed to copy audio file: \(error.localizedDescription)")
            await completeWithError(message: "Failed to save audio")
        }
    }

    private func openMainApp() async {
        statusLabel.text = "Opening VivaDicta..."

        // Use URL scheme to open main app
        guard let url = URL(string: "vivadicta://transcribe-shared") else {
            logger.error("Failed to create URL for main app")
            completeRequest()
            return
        }

        // Open URL via responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                let success = await application.open(url)
                logger.info("Opened main app: \(success)")
                completeRequest()
                return
            }
            responder = responder?.next
        }

        // Fallback: complete after a short delay
        try? await Task.sleep(for: .milliseconds(500))
        completeRequest()
    }

    private func completeWithError(message: String) async {
        statusLabel.text = message
        activityIndicator.stopAnimating()

        // Show error briefly then dismiss
        try? await Task.sleep(for: .seconds(1.5))
        let error = NSError(domain: "com.antonnovoselov.VivaDicta.ShareExtension", code: -1)
        extensionContext?.cancelRequest(withError: error)
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
