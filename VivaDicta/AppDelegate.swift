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
import FirebaseCore

final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let logger = Logger(category: .appDelegate)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.logInfo("🚀 didFinishLaunchingWithOptions - state: \(application.applicationState.debugDescription)")
        FirebaseApp.configure()
        BackgroundTaskService.registerBGTaskHandler()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.logInfo("🚀 applicationDidBecomeActive")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.logInfo("🚀 applicationDidEnterBackground")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.logInfo("🚀 applicationWillEnterForeground")
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
    private let logger = Logger(category: .sceneDelegate)

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
        guard let appState = SceneDelegate.appState else { return }

        switch shortcutItem.type {
        case QuickActionType.startRecord.rawValue:
            appState.shouldStartRecording = true
        case QuickActionType.search.rawValue:
            appState.shouldFocusSearch = true
        case QuickActionType.askAI.rawValue:
            appState.shouldShowChats = true
        default:
            break
        }
    }
}

extension UIApplication.State {
    var debugDescription: String {
        switch self {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown"
        }
    }
}

#endif

