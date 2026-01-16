//
//  RateAppManager.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.01.16
//

import Foundation
import StoreKit

/// Manager for handling app rating requests.
/// Requests are throttled based on launch count, days since install, and time since last request.
@MainActor
enum RateAppManager {

    // MARK: - Configuration

    /// Minimum number of app launches before requesting a rating.
    private static let minimumLaunchCount = 5

    /// Minimum number of days since first launch before requesting a rating.
    private static let minimumDaysSinceInstall = 3

    /// Minimum days since install for passive users who may not launch frequently.
    /// Used as an alternative to launch-count-based conditions.
    private static let minimumDaysSinceInstallWide = 30

    /// Minimum number of days between rating requests.
    private static let minimumDaysBetweenRequests = 90

    // MARK: - Private

    private static var defaults: UserDefaults {
        UserDefaultsStorage.appPrivate
    }

    /// The date when we last requested a rating from the user.
    private static var lastRatingRequestDate: Date? {
        get { defaults.object(forKey: UserDefaultsStorage.Keys.lastRatingRequestDate) as? Date }
        set { defaults.set(newValue, forKey: UserDefaultsStorage.Keys.lastRatingRequestDate) }
    }

    /// Number of days since the last rating request.
    private static var daysSinceLastRequest: Int? {
        guard let lastRequest = lastRatingRequestDate else { return nil }
        let components = Calendar.current.dateComponents([.day], from: lastRequest, to: Date())
        return components.day
    }

    /// Returns true if enough time has passed since the last rating request (or if never requested).
    private static var hasEnoughTimeSinceLastRequest: Bool {
        guard let daysSinceLast = daysSinceLastRequest else { return true }
        return daysSinceLast >= minimumDaysBetweenRequests
    }

    // MARK: - Public

    /// Checks if conditions are met and requests an app rating if appropriate.
    /// Call this after successful user actions (transcription, enhancement, etc.).
    static func requestReviewIfAppropriate() {
        guard shouldRequestReview() else { return }
        presentReviewRequest()
    }

    /// Checks if conditions are met for app start rating request.
    /// Requires at least one saved transcription in addition to standard conditions.
    /// Call this at app start (e.g., in MainView.onAppear).
    /// - Parameter transcriptionCount: The number of saved transcriptions.
    static func requestReviewOnAppStartIfAppropriate(transcriptionCount: Int) {
        // Require at least one transcription to ensure the user has actually used
        // the app's core functionality before being asked to rate
        guard transcriptionCount >= 1 else { return }
        
        let usualRule = shouldRequestReview()
        let wideRule = shouldRequestReviewWide()
        guard usualRule || wideRule else { return }
        presentReviewRequest()
    }

    // MARK: - Private

    private static func presentReviewRequest() {
        // Record the request date before showing
        lastRatingRequestDate = Date()

        // Request review using StoreKit
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    /// Returns true if all conditions are met for requesting a review.
    private static func shouldRequestReview() -> Bool {
        // Check minimum launch count
        guard AppLaunchTracker.launchCount >= minimumLaunchCount else {
            return false
        }

        // Check minimum days since install
        guard AppLaunchTracker.daysSinceFirstLaunch >= minimumDaysSinceInstall else {
            return false
        }

        // Check if enough time has passed since last request
        guard hasEnoughTimeSinceLastRequest else {
            return false
        }

        return true
    }
    
    /// Alternative conditions for passive users who don't launch frequently.
    /// Only requires time since install (no launch count requirement).
    private static func shouldRequestReviewWide() -> Bool {
        // Check minimum days since install
        guard AppLaunchTracker.daysSinceFirstLaunch >= minimumDaysSinceInstallWide else {
            return false
        }

        // Check if enough time has passed since last request
        guard hasEnoughTimeSinceLastRequest else {
            return false
        }

        return true
    }
}
