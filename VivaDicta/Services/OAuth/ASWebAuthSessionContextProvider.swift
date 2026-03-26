// Copyright © 2026 Anton Novoselov. All rights reserved.

import AuthenticationServices
import UIKit

@MainActor
class ASWebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ASWebAuthSessionContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}
