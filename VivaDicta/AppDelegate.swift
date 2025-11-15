//
//  AppDelegate.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2025.11.15
//

#if !os(macOS)
import UIKit

final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private var defferedQuickAction: UIApplicationShortcutItem? = nil

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



