//
//  LoggerExtension.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.10.16
//

import Foundation
import os

extension Logger {
    /// Check if print logs are enabled via environment variable
    private nonisolated static var printLogsEnabled: Bool {
        ProcessInfo.processInfo.environment["ENABLE_PRINT_LOGS"] == "1"
    }

    /// Log info level with optional print statement
    nonisolated func logInfo(_ message: String) {
        self.info("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log debug level with optional print statement
    nonisolated func logDebug(_ message: String) {
        self.debug("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log error level with optional print statement
    nonisolated func logError(_ message: String) {
        self.error("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log warning level with optional print statement
    nonisolated func logWarning(_ message: String) {
        self.warning("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }

    /// Log notice level with optional print statement
    nonisolated func logNotice(_ message: String) {
        self.notice("\(message, privacy: .public)")

        if Self.printLogsEnabled {
            print(message)
        }
    }
}
