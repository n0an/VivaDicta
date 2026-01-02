//
//  NetworkRetry.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.02
//

import Foundation
import os

enum NetworkRetry {
    static let defaultTimeout: TimeInterval = 120
    static let maxRetries = 2
    static let initialRetryDelay: Duration = .seconds(1)

    /// Executes an async operation with retry logic for transient failures.
    /// - Parameters:
    ///   - logger: Logger for recording retry attempts
    ///   - operation: The async throwing operation to execute
    /// - Returns: The result of the operation
    static func withRetry<T>(
        logger: Logger,
        operation: () async throws -> T
    ) async throws -> T {
        var retries = 0
        var currentDelay = initialRetryDelay

        while true {
            do {
                try Task.checkCancellation()
                return try await operation()
            } catch let error as CloudTranscriptionError {
                guard shouldRetry(error: error, retries: retries) else {
                    throw error
                }
                retries += 1
                logger.warning("Request failed, retrying in \(currentDelay)... (Attempt \(retries)/\(maxRetries))")
                try await Task.sleep(for: currentDelay)
                currentDelay *= 2
            } catch {
                guard shouldRetryURLError(error: error, retries: retries) else {
                    throw wrapIfNetworkError(error)
                }
                retries += 1
                logger.warning("Network error, retrying in \(currentDelay)... (Attempt \(retries)/\(maxRetries))")
                try await Task.sleep(for: currentDelay)
                currentDelay *= 2
            }
        }
    }

    private static func shouldRetry(error: CloudTranscriptionError, retries: Int) -> Bool {
        guard retries < maxRetries else { return false }

        switch error {
        case .networkError:
            return true
        case .apiRequestFailed(let statusCode, _):
            // Retry on server errors (5xx) and rate limiting (429)
            return (500...599).contains(statusCode) || statusCode == 429
        default:
            return false
        }
    }

    private static func shouldRetryURLError(error: Error, retries: Int) -> Bool {
        guard retries < maxRetries else { return false }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }

        let retryableCodes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorCannotConnectToHost
        ]
        return retryableCodes.contains(nsError.code)
    }

    private static func wrapIfNetworkError(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return CloudTranscriptionError.networkError(error)
        }
        return error
    }
}
