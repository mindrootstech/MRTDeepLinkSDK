import Foundation

public typealias MRTDeepLinkHandler = (MRTDeepLinkPayload) -> Void

public final class MRTDeepLink: @unchecked Sendable {
    public static let shared = MRTDeepLink()

    private var configuration: MRTDeepLinkConfiguration?
    private var handler: MRTDeepLinkHandler?
    private var deferredMatchHandler: MRTDeferredMatchDebugHandler?
    private var deferredMatchRequestHandler: MRTDeferredMatchDebugRequestHandler?
    private var pendingPayload: MRTDeepLinkPayload?
    private var receivedDirectDeepLinkThisSession = false
    private var deferredMatchInFlight = false
    private var lastDeferredMatchResponse: MRTDeferredMatchResponse?
    private var lastMatchRequestJSON: String?
    private var launchClickSessionId: String?
    private let lock = NSLock()

    private static let deferredMatchReportedKey = "com.mrtdeeplink.deferred.match.reported"
    private static let deferredDeliveredKey = "com.mrtdeeplink.deferred.delivered"

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    public var currentDeferredMatchDebugResponse: MRTDeferredMatchResponse? {
        lock.lock()
        defer { lock.unlock() }
        return lastDeferredMatchResponse
    }

    public var currentMatchDebugRequestJSON: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastMatchRequestJSON
    }

    @discardableResult
    public func configure(
        apiKey: String,
        debugLogging: Bool = false,
        serverURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        universalLinkDomain: String? = nil,
        customURLScheme: String? = nil
    ) -> MRTDeepLink {
        return configure(
            MRTDeepLinkConfiguration(
                apiKey: apiKey,
                debugLogging: debugLogging,
                serverURL: serverURL,
                universalLinkDomain: universalLinkDomain,
                customURLScheme: customURLScheme
            )
        )
    }

    @discardableResult
    public func configure(_ configuration: MRTDeepLinkConfiguration) -> MRTDeepLink {
        lock.lock()
        self.configuration = configuration
        lock.unlock()

        log("SDK configured (deferred match)")
        beginDeferredMatchIfNeeded()
        return self
    }

    public func onDeferredMatchDebug(_ handler: @escaping MRTDeferredMatchDebugHandler) {
        lock.lock()
        deferredMatchHandler = handler
        let response = lastDeferredMatchResponse
        lock.unlock()

        if let response {
            DispatchQueue.main.async { handler(.success(response)) }
        }
    }

    public func onDeferredMatchDebugRequest(_ handler: @escaping MRTDeferredMatchDebugRequestHandler) {
        lock.lock()
        deferredMatchRequestHandler = handler
        let json = lastMatchRequestJSON
        lock.unlock()

        if let json {
            DispatchQueue.main.async { handler(json) }
        }
    }

    public func runDeferredMatchDebug(clickSessionId: String? = nil) {
        performDeferredMatch(
            options: MRTDeferredMatchOptions(clickSessionId: clickSessionId),
            markReported: false
        )
    }

    public func onDeepLink(_ handler: @escaping MRTDeepLinkHandler) {
        lock.lock()
        self.handler = handler
        lock.unlock()
        deliverPendingPayloadIfNeeded()
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        captureLaunchClickSessionId(from: url)

        guard let configuration else {
            log("Received URL before configure(): \(url.absoluteString)")
            return false
        }

        guard let payload = MRTDeepLinkParser.parse(url: url, configuration: configuration) else {
            log("Ignored unsupported URL: \(url.absoluteString)")
            return false
        }

        receivedDirectDeepLinkThisSession = true
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

        logDeepLinkPayload(payload)

        if let handler {
            DispatchQueue.main.async { handler(payload) }
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

        DispatchQueue.main.async { handler(payload) }
    }

    private func beginDeferredMatchIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.deferredMatchReportedKey) else { return }

        lock.lock()
        let sessionId = launchClickSessionId
        lock.unlock()

        performDeferredMatch(
            options: MRTDeferredMatchOptions(clickSessionId: sessionId),
            markReported: true
        )
    }

    private func captureLaunchClickSessionId(from url: URL) {
        guard let sessionId = MRTDeepLinkParser.parseClickSessionId(from: url) else { return }
        lock.lock()
        if launchClickSessionId == nil {
            launchClickSessionId = sessionId
        }
        lock.unlock()
    }

    private func performDeferredMatch(options: MRTDeferredMatchOptions, markReported: Bool) {
        lock.lock()
        if deferredMatchInFlight {
            lock.unlock()
            return
        }
        guard let config = configuration else {
            lock.unlock()
            return
        }
        let storedSessionId = launchClickSessionId
        deferredMatchInFlight = true
        lock.unlock()

        let resolved = MRTDeferredMatchOptions(
            clickSessionId: options.clickSessionId ?? storedSessionId
        )
        let debugLogging = config.debugLogging

        Task {
            defer {
                lock.lock()
                deferredMatchInFlight = false
                lock.unlock()
            }

            let output = await MRTDeferredMatchClient.run(
                configuration: config,
                options: resolved,
                debugLogging: debugLogging
            )

            if let requestJSON = output.requestJSON {
                lock.lock()
                lastMatchRequestJSON = requestJSON
                let requestHandler = deferredMatchRequestHandler
                lock.unlock()
                if let requestHandler {
                    DispatchQueue.main.async { requestHandler(requestJSON) }
                }
            }

            switch output.result {
            case .success(let response):
                if markReported {
                    UserDefaults.standard.set(true, forKey: Self.deferredMatchReportedKey)
                }

                lock.lock()
                lastDeferredMatchResponse = response
                let matchHandler = deferredMatchHandler
                lock.unlock()

                log("Deferred match matched=\(response.matched) tier=\(response.tier ?? "-") confidence=\(response.confidence ?? "-")")

                if let matchHandler {
                    DispatchQueue.main.async { matchHandler(.success(response)) }
                }

                guard response.matched else { return }
                guard !UserDefaults.standard.bool(forKey: Self.deferredDeliveredKey) else { return }

                lock.lock()
                let receivedDirect = receivedDirectDeepLinkThisSession
                let hasPending = pendingPayload != nil
                lock.unlock()
                guard !receivedDirect, !hasPending else { return }

                if let payload = MRTDeferredMatchClient.makeDeferredPayload(
                    response: response,
                    configuration: config
                ) {
                    UserDefaults.standard.set(true, forKey: Self.deferredDeliveredKey)
                    log("Deferred link: \(payload.url.absoluteString)")
                    deliver(payload)
                }

            case .failure(let error):
                log("Deferred match failed: \(error.localizedDescription ?? "unknown")")
                lock.lock()
                let matchHandler = deferredMatchHandler
                lock.unlock()
                if let matchHandler {
                    DispatchQueue.main.async { matchHandler(.failure(error)) }
                }
            }
        }
    }

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        MRTSDKLogger.debug(message, enabled: true)
    }

    private func logDeepLinkPayload(_ payload: MRTDeepLinkPayload) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }

        print("══════════════════════════════════════")
        print("🔗 [MRTDeepLinkSDK] DEEP LINK")
        print("URL:      \(payload.url.absoluteString)")
        print("Path:     \(payload.path)")
        print("Source:   \(payload.source.rawValue)")
        print("Deferred: \(payload.isDeferred ? "YES" : "no")")
        print("══════════════════════════════════════")
    }
}
