import Foundation

public typealias MRTDeepLinkHandler = (MRTDeepLinkPayload) -> Void

public final class MRTDeepLink: @unchecked Sendable {
    public static let shared = MRTDeepLink()

    private var configuration: MRTDeepLinkConfiguration?
    private var handler: MRTDeepLinkHandler?
    private var pendingPayload: MRTDeepLinkPayload?
    private let lock = NSLock()

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    @discardableResult
    public func configure(_ configuration: MRTDeepLinkConfiguration) -> MRTDeepLink {
        lock.lock()
        self.configuration = configuration
        lock.unlock()

        log("Configured for app: \(configuration.appIdentifier)")
        deliverPendingPayloadIfNeeded()
        return self
    }

    public func onDeepLink(_ handler: @escaping MRTDeepLinkHandler) {
        lock.lock()
        self.handler = handler
        lock.unlock()

        deliverPendingPayloadIfNeeded()
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        guard let configuration else {
            log("Received URL before configure(): \(url.absoluteString)")
            return false
        }

        guard let payload = MRTDeepLinkParser.parse(url: url, configuration: configuration) else {
            log("Ignored unsupported URL: \(url.absoluteString)")
            return false
        }

        return deliver(payload)
    }

    @discardableResult
    public func handle(userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return handle(url: url)
    }

    public func consumePendingDeepLink() -> MRTDeepLinkPayload? {
        lock.lock()
        defer { lock.unlock() }
        let payload = pendingPayload
        pendingPayload = nil
        return payload
    }

    @discardableResult
    private func deliver(_ payload: MRTDeepLinkPayload) -> Bool {
        lock.lock()
        let handler = handler
        lock.unlock()

        log("Deep link received: \(payload.url.absoluteString)")

        if let handler {
            DispatchQueue.main.async {
                handler(payload)
            }
            return true
        }

        lock.lock()
        pendingPayload = payload
        lock.unlock()
        return true
    }

    private func deliverPendingPayloadIfNeeded() {
        lock.lock()
        let payload = pendingPayload
        let handler = handler
        lock.unlock()

        guard let payload, let handler else { return }

        lock.lock()
        pendingPayload = nil
        lock.unlock()

        DispatchQueue.main.async {
            handler(payload)
        }
    }

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        print("[MRTDeepLinkSDK] \(message)")
    }
}
