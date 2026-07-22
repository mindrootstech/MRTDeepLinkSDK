import SwiftUI

public struct MRTDeepLinkHandlerModifier: ViewModifier {
    private let handler: MRTDeepLinkHandler

    public init(handler: @escaping MRTDeepLinkHandler) {
        self.handler = handler
        // Register immediately — cold-start Universal Links often arrive
        // before the first `onAppear`.
        MRTDeepLink.shared.onDeepLink(handler)
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                MRTDeepLink.shared.onDeepLink(handler)
            }
            .onOpenURL { url in
                _ = MRTDeepLink.shared.handle(url: url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                _ = MRTDeepLink.shared.handle(userActivity: activity)
            }
    }
}

public extension View {
    func handleMRTDeepLinks(_ handler: @escaping MRTDeepLinkHandler) -> some View {
        modifier(MRTDeepLinkHandlerModifier(handler: handler))
    }
}
