// Copyright © 2026 Anton Novoselov. All rights reserved.

#if os(iOS)
import AuthenticationServices
import UIKit

@MainActor
public class ASWebAuthSessionContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = ASWebAuthSessionContextProvider()

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return UIWindow()
        }
        return window
    }
}
#endif
