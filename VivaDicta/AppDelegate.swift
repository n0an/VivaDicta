//
//  AppDelegate.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.15
//

#if !os(macOS)
import UIKit
import ActivityKit
import os

final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "AppDelegate")

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.log("🔴 App will terminate - cleaning up Live Activities")

        // End all Live Activities immediately before termination
        Task {
            for activity in Activity<VivaDictaLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var defferedQuickAction: UIApplicationShortcutItem? = nil
    private let logger = Logger(subsystem: "com.antonnovoselov.VivaDicta", category: "SceneDelegate")

    // Store reference to AppState for quick action handling
    static weak var appState: AppState?

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let shortcut = defferedQuickAction {
            let _ = handleShortcutItem(shortcut)
        }
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem {
            defferedQuickAction = shortcutItem
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        logger.log("🔴 Scene did disconnect - cleaning up Live Activities")

        // End all Live Activities when scene disconnects
        // This handles both user force-quit and system termination
        Task {
            for activity in Activity<VivaDictaLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == QuickActionType.startRecord.rawValue {
            // Trigger recording through AppState
            if let appState = SceneDelegate.appState {
                // Set flag to trigger recording when the app finishes launching
                appState.shouldStartRecording = true
            }
        }
    }
}

#endif



