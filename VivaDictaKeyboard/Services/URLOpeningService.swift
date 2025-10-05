//
//  URLOpeningService.swift
//  VivaDictaKeyboard
//
//  Service responsible for opening URLs from keyboard extension
//

import UIKit
import os

/// Protocol for URL opening service to enable mocking in tests
public protocol URLOpening {
    func openURL(_ url: URL, completion: ((Bool) -> Void)?)
}

/// Service that handles opening URLs via different methods with fallback strategies
public class URLOpeningService: URLOpening {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "URLOpening")
    private weak var extensionContext: NSExtensionContext?
    private weak var responderChainRoot: UIResponder?

    // MARK: - Initialization

    public init(extensionContext: NSExtensionContext?, responderChainRoot: UIResponder?) {
        self.extensionContext = extensionContext
        self.responderChainRoot = responderChainRoot
    }

    // MARK: - Public Methods

    /// Open a URL using the best available method with automatic fallback
    public func openURL(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        logger.info("🎤 Opening URL: \(url.absoluteString)")

        // Method 1: Try extensionContext.open (primary method)
        extensionContext?.open(url) { [weak self] success in
            if success {
                self?.logger.info("🎤 ✅ Successfully opened URL via extensionContext")
                completion?(true)
            } else {
                self?.logger.info("🎤 ⚠️ extensionContext.open failed, trying alternative methods...")
                Task { @MainActor in
                    self?.tryAlternativeURLOpening(url, completion: completion)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func tryAlternativeURLOpening(_ url: URL, completion: ((Bool) -> Void)?) {
        logger.info("🎤 Trying alternative URL opening methods...")

        // Method 2: Try UIApplication directly via key-value coding
        if let sharedApp = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
            logger.info("🎤 Found UIApplication using sharedApplication")

            if sharedApp.canOpenURL(url) {
                logger.info("🎤 canOpenURL returned true")
                sharedApp.open(url, options: [:]) { [weak self] success in
                    if success {
                        self?.logger.info("🎤 ✅ Successfully opened URL via UIApplication.open")
                        completion?(true)
                    } else {
                        self?.logger.error("🎤 ❌ UIApplication.open failed")
                        Task { @MainActor in
                            self?.openURLViaResponderChain(url, completion: completion)
                        }
                    }
                }
                return
            } else {
                logger.warning("🎤 ⚠️ canOpenURL returned false")
            }
        } else {
            logger.info("🎤 Could not get UIApplication via sharedApplication")
        }

        // Fallback to responder chain method
        openURLViaResponderChain(url, completion: completion)
    }

    private func openURLViaResponderChain(_ url: URL, completion: ((Bool) -> Void)?) {
        var optionalResponder: UIResponder? = responderChainRoot
        let selector = NSSelectorFromString("openURL:")

        while let responder = optionalResponder {
            if responder.responds(to: selector) {
                logger.info("🎤 Found responder that responds to openURL:")
                responder.perform(selector, with: url)
                logger.info("🎤 ✅ Attempted to open URL via responder chain")
                completion?(true)
                return
            }
            optionalResponder = responder.next
        }

        logger.error("🎤 ❌ All URL opening methods failed")
        completion?(false)
    }
}
