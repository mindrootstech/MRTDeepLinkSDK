import SwiftUI

public struct CliqItHandlerModifier: ViewModifier {
    private let handler: CliqItHandler

    public init(handler: @escaping CliqItHandler) {
        self.handler = handler
        // Register immediately — cold-start Universal Links often arrive
        // before the first `onAppear`.
        CliqItSDK.shared.onLinkReceived(handler)
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                CliqItSDK.shared.onLinkReceived(handler)
            }
            .onOpenURL { url in
                _ = CliqItSDK.shared.handle(url: url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                _ = CliqItSDK.shared.handle(userActivity: activity)
            }
    }
}

public extension View {
    func handleCliqItLinkReceived(_ handler: @escaping CliqItHandler) -> some View {
        modifier(CliqItHandlerModifier(handler: handler))
    }

    @available(*, deprecated, renamed: "handleCliqItLinkReceived")
    func handleCliqItDeepLinks(_ handler: @escaping CliqItHandler) -> some View {
        handleCliqItLinkReceived(handler)
    }
}
