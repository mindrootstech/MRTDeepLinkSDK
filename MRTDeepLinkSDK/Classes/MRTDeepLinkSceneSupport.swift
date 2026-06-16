#if canImport(UIKit)
import UIKit

/// Helpers for UIKit apps that use `UIScene` (Storyboard / SceneDelegate lifecycle).
public enum MRTDeepLinkSceneSupport {
    /// Call from `scene(_:willConnectTo:options:)` to handle cold-start deep links.
    public static func handle(connectionOptions: UIScene.ConnectionOptions) {
        for userActivity in connectionOptions.userActivities {
            _ = MRTDeepLink.shared.handle(userActivity: userActivity)
        }
        for context in connectionOptions.urlContexts {
            _ = MRTDeepLink.shared.handle(url: context.url)
        }
    }

    /// Call from `scene(_:continue:)` for Universal Links while the app is running.
    @discardableResult
    public static func handle(userActivity: NSUserActivity) -> Bool {
        MRTDeepLink.shared.handle(userActivity: userActivity)
    }

    /// Call from `scene(_:openURLContexts:)` for custom URL schemes.
    public static func handle(urlContexts: Set<UIOpenURLContext>) {
        for context in urlContexts {
            _ = MRTDeepLink.shared.handle(url: context.url)
        }
    }
}
#endif
