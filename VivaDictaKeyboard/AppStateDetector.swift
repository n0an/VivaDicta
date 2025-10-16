//
//  AppStateDetector.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.10.02
//

import Foundation
import os

/// Detects the main app's state (active/suspended) for the keyboard extension
//public class AppStateDetector {
//
//    // MARK: - Types
//    public enum AppState {
//        case suspended      // App is suspended and cannot receive Darwin notifications
//        case active        // App is not suspended and ready to receive Darwin notifications
//    }
//
//    // MARK: - Properties
//    private let sharedDefaults: UserDefaults?
//    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "KeyboardExtension")
//
//    // MARK: - Initialization
//    public init() {
//        sharedDefaults = UserDefaultsStorage.shared
//        logger.logInfo("🔍 AppStateDetector initialized")
//    }
//
//    // MARK: - Public Methods
//
//    /// Detect the current state of the main app
//    public func detectAppState() -> AppState {
//        guard let sharedDefaults = sharedDefaults else {
//            logger.logError("🔍 ❌ Failed to access shared UserDefaults")
//            return .suspended
//        }
//
//        // Check the last heartbeat timestamp
//        let lastHeartbeat = sharedDefaults.double(forKey: AppGroupConfig.heartbeatKey)
//
//        // If heartbeat is 0, app has never been active or explicitly marked as inactive
//        guard lastHeartbeat > 0 else {
//            logger.logInfo("🔍 App heartbeat is 0 - app is suspended")
//            return .suspended
//        }
//
//        // Calculate time since last heartbeat
//        let currentTime = Date().timeIntervalSince1970
//        let timeSinceLastHeartbeat = currentTime - lastHeartbeat
//
//        // Check if heartbeat is recent enough
//        if timeSinceLastHeartbeat < AppGroupConfig.heartbeatThreshold {
//            logger.logDebug("🔍 App is active (heartbeat age: \(String(format: "%.1f", timeSinceLastHeartbeat))s)")
//            return .active
//        } else {
//            logger.logInfo("🔍 App is suspended (heartbeat age: \(String(format: "%.1f", timeSinceLastHeartbeat))s)")
//            return .suspended
//        }
//    }
//
//    /// Check if the main app is currently active (convenience method)
//    public func isMainAppActive() -> Bool {
//        return detectAppState() == .active
//    }
//
//    /// Get the age of the last heartbeat in seconds (for debugging)
//    public func heartbeatAge() -> TimeInterval? {
//        guard let sharedDefaults = sharedDefaults else { return nil }
//
//        let lastHeartbeat = sharedDefaults.double(forKey: AppGroupConfig.heartbeatKey)
//        guard lastHeartbeat > 0 else { return nil }
//
//        return Date().timeIntervalSince1970 - lastHeartbeat
//    }
//}
