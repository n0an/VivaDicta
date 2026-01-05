//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Anton Novoselov on 05.01.2026.
//

import UIKit
import UniformTypeIdentifiers
import os

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
        processSharedAudio()
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

    private func processSharedAudio() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            logger.error("No extension context or input items")
            completeWithError(message: "No audio file found")
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
                        loadAudioFile(from: provider, type: audioType)
                        return
                    }
                }

                // Also check for generic public.audio
                if provider.hasItemConformingToTypeIdentifier("public.audio") {
                    logger.info("Found generic audio attachment")
                    loadAudioFile(from: provider, typeIdentifier: "public.audio")
                    return
                }
            }
        }

        logger.error("No audio attachment found in shared items")
        completeWithError(message: "No audio file found")
    }

    private func loadAudioFile(from provider: NSItemProvider, type: UTType) {
        loadAudioFile(from: provider, typeIdentifier: type.identifier)
    }

    private func loadAudioFile(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to load audio file: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.completeWithError(message: "Failed to load audio")
                }
                return
            }

            guard let sourceURL = url else {
                self.logger.error("No URL returned from provider")
                DispatchQueue.main.async {
                    self.completeWithError(message: "Failed to access audio")
                }
                return
            }

            self.logger.info("Loaded audio file from: \(sourceURL.lastPathComponent)")
            self.copyAndShareAudio(from: sourceURL)
        }
    }

    private func copyAndShareAudio(from sourceURL: URL) {
        // Get shared container directory
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            logger.error("Failed to get app group container URL")
            DispatchQueue.main.async {
                self.completeWithError(message: "Storage error")
            }
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
            DispatchQueue.main.async {
                self.openMainApp()
            }

        } catch {
            logger.error("Failed to copy audio file: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.completeWithError(message: "Failed to save audio")
            }
        }
    }

    private func openMainApp() {
        statusLabel.text = "Opening VivaDicta..."

        // Use URL scheme to open main app
        let urlString = "vivadicta://transcribe-shared"
        guard let url = URL(string: urlString) else {
            logger.error("Failed to create URL for main app")
            completeRequest()
            return
        }

        // Open URL via responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                application.open(url, options: [:]) { [weak self] success in
                    self?.logger.info("Opened main app: \(success)")
                    self?.completeRequest()
                }
                return
            }
            responder = responder?.next
        }

        // Fallback: use openURL selector (works for Share Extensions)
        if let openURL = URL(string: urlString) {
            let selector = sel_registerName("openURL:")
            var responderChain: UIResponder? = self
            while responderChain != nil {
                if responderChain!.responds(to: selector) {
                    responderChain!.perform(selector, with: openURL)
                    logger.info("Opened main app via responder chain")
                    break
                }
                responderChain = responderChain?.next
            }
        }

        // Complete after a short delay to allow URL to open
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.completeRequest()
        }
    }

    private func completeWithError(message: String) {
        statusLabel.text = message
        activityIndicator.stopAnimating()

        // Show error briefly then dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let error = NSError(domain: "com.antonnovoselov.VivaDicta.ShareExtension", code: -1)
            self?.extensionContext?.cancelRequest(withError: error)
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
