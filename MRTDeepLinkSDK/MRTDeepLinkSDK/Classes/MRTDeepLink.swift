import Foundation

public typealias MRTDeepLinkHandler = (MRTDeepLinkPayload) -> Void

public extension Notification.Name {
    static let mrtDeepLinkIgnored = Notification.Name("MRTDeepLink.ignoredURL")
}

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

    /// Last WebView probe result (canvas / WebGL / audio / clock skew).
    /// Note: on iOS these are often identical across devices — use `combinedFingerprint`.
    public var currentWebFingerprint: MRTWebFingerprint? {
        MRTWebFingerprintCollector.lastResult
    }

    /// SHA-256 over native locale/a11y/screen + WebView signals. Varies per user settings even when canvas/WebGL collide.
    public var combinedFingerprint: MRTCombinedFingerprint {
        MRTCombinedFingerprintBuilder.build(web: currentWebFingerprint)
    }

    /// Runs the hidden WKWebView probe and returns the fingerprint.
    public func collectWebFingerprint() async -> MRTWebFingerprint? {
        lock.lock()
        let debug = configuration?.debugLogging == true
        lock.unlock()
        return await MRTWebFingerprintCollector.collect(debugLogging: debug)
    }

    /// WebView probe + combined native/web digest.
    public func collectCombinedFingerprint() async -> MRTCombinedFingerprint {
        _ = await collectWebFingerprint()
        return combinedFingerprint
    }

    /// True while a deferred match network + fingerprint collect is running.
    public var isDeferredMatchInFlight: Bool {
        lock.lock()
        defer { lock.unlock() }
        return deferredMatchInFlight
    }

    /// True after a successful deferred match was reported for this install.
    public var hasDeferredMatchBeenReported: Bool {
        UserDefaults.standard.bool(forKey: Self.deferredMatchReportedKey)
    }

    @discardableResult
    public func configure(
        apiKey: String,
        debugLogging: Bool = false,
        serverURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        universalLinkDomain: String? = nil,
        customURLScheme: String? = nil,
        clipboardMatchEnabled: Bool = false
    ) -> MRTDeepLink {
        return configure(
            MRTDeepLinkConfiguration(
                apiKey: apiKey,
                debugLogging: debugLogging,
                serverURL: serverURL,
                universalLinkDomain: universalLinkDomain,
                customURLScheme: customURLScheme,
                clipboardMatchEnabled: clipboardMatchEnabled
            )
        )
    }

    /// Silent clipboard check + conditional read for a copied SmartLink token.
    /// Returns a session token only if the clipboard holds a web URL with a session param.
    /// The read step may show the iOS paste prompt; the silent detect step never does.
    public func readClipboardMatchToken() async -> String? {
        await MRTClipboardMatchToken.readIfLinkPresent()
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
            // Buffer so onDeepLink can retry after configure if needed.
            lock.lock()
            pendingPayload = MRTDeepLinkPayload(
                url: url,
                path: url.path.isEmpty ? "/" : url.path,
                pathComponents: url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty },
                queryParameters: Self.queryItems(from: url),
                source: .unknown
            )
            lock.unlock()
            return false
        }

        guard let payload = MRTDeepLinkParser.parse(url: url, configuration: configuration) else {
            log("Ignored unsupported URL: \(url.absoluteString) (host=\(url.host ?? "-") expected=\(configuration.universalLinkDomain ?? "-") scheme=\(configuration.customURLScheme ?? "-"))")
            NotificationCenter.default.post(
                name: .mrtDeepLinkIgnored,
                object: nil,
                userInfo: ["url": url.absoluteString]
            )
            return false
        }

        receivedDirectDeepLinkThisSession = true
        return deliver(payload)
    }

    private static func queryItems(from url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return [:]
        }
        var params: [String: String] = [:]
        for item in items {
            params[item.name] = item.value ?? ""
        }
        return params
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
        let clipboardEnabled = configuration?.clipboardMatchEnabled == true
        lock.unlock()

        // Universal Link already carried a session — no clipboard needed.
        guard sessionId == nil, clipboardEnabled else {
            performDeferredMatch(
                options: MRTDeferredMatchOptions(clickSessionId: sessionId),
                markReported: true
            )
            return
        }

        Task {
            let token = await MRTClipboardMatchToken.readIfLinkPresent()
            performDeferredMatch(
                options: MRTDeferredMatchOptions(clickSessionId: token),
                markReported: true
            )
        }
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
