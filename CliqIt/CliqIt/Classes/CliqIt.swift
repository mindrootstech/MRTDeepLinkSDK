import Foundation

public typealias CliqItHandler = (CliqItPayload) -> Void

public extension Notification.Name {
    static let cliqItDeepLinkIgnored = Notification.Name("CliqIt.ignoredURL")
}

public final class CliqItSDK: @unchecked Sendable {
    public static let shared = CliqItSDK()

    private var configuration: CliqItConfiguration?
    private var handler: CliqItHandler?
    private var deferredMatchHandler: CliqItDeferredMatchDebugHandler?
    private var deferredMatchOutcomeHandler: CliqItDeferredMatchHandler?
    private var deferredMatchRequestHandler: CliqItDeferredMatchDebugRequestHandler?
    /// Fires after GET `/api/v1/sdk/link/{slug}` on direct opens.
    private var directLinkLookupHandler: CliqItDirectLinkLookupHandler?
    private var verifyHandler: CliqItVerifyHandler?
    private var pendingPayload: CliqItPayload?
    private var receivedDirectDeepLinkThisSession = false
    private var deferredMatchInFlight = false
    private var lastDeferredMatchResponse: CliqItDeferredMatchResponse?
    private var lastMatchRequestJSON: String?
    private var lastDirectLinkDetails: CliqItLinkDetails?
    private var lastVerifyJSON: String?
    private var lastVerifyOutcome: CliqItVerifyOutcome?
    private var launchClickSessionId: String?
    private let lock = NSLock()

    private static let deferredMatchReportedKey = "com.cliqit.deferred.match.reported"
    private static let deferredDeliveredKey = "com.cliqit.deferred.delivered"

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    public var currentDeferredMatchDebugResponse: CliqItDeferredMatchResponse? {
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
    public var currentWebFingerprint: CliqItWebFingerprint? {
        CliqItWebFingerprintCollector.lastResult
    }

    /// SHA-256 over native locale/a11y/screen + WebView signals. Varies per user settings even when canvas/WebGL collide.
    public var combinedFingerprint: CliqItCombinedFingerprint {
        CliqItCombinedFingerprintBuilder.build(web: currentWebFingerprint)
    }

    /// Runs the hidden WKWebView probe and returns the fingerprint.
    public func collectWebFingerprint() async -> CliqItWebFingerprint? {
        lock.lock()
        let debug = configuration?.debugLogging == true
        lock.unlock()
        return await CliqItWebFingerprintCollector.collect(debugLogging: debug)
    }

    /// WebView probe + combined native/web digest.
    public func collectCombinedFingerprint() async -> CliqItCombinedFingerprint {
        _ = await collectWebFingerprint()
        return combinedFingerprint
    }

    public var currentDirectLinkDetails: CliqItLinkDetails? {
        lock.lock()
        defer { lock.unlock() }
        return lastDirectLinkDetails
    }

    public var currentVerifyJSON: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastVerifyJSON
    }

    public var currentVerifyOutcome: CliqItVerifyOutcome? {
        lock.lock()
        defer { lock.unlock() }
        return lastVerifyOutcome
    }

    /// True while a deferred match network + fingerprint collect is running.
    public var isDeferredMatchInFlight: Bool {
        lock.lock()
        defer { lock.unlock() }
        return deferredMatchInFlight
    }

    /// True after a **matched** deferred result was persisted for this install (notMatched does not set this).
    public var hasDeferredMatchBeenReported: Bool {
        UserDefaults.standard.bool(forKey: Self.deferredMatchReportedKey)
    }

    @discardableResult
    public func configure(apiKey: String) -> CliqItSDK {
        return configure(CliqItConfiguration(apiKey: apiKey))
    }

    @discardableResult
    public func configure(_ configuration: CliqItConfiguration) -> CliqItSDK {
        lock.lock()
        self.configuration = configuration
        lock.unlock()

        print("✅ [CliqIt] configured")
        CliqItVerifyClient.verifyInBackground(configuration: configuration) { [weak self] outcome, raw in
            guard let self else { return }
            self.lock.lock()
            self.lastVerifyOutcome = outcome
            if let raw { self.lastVerifyJSON = raw }
            let handler = self.verifyHandler
            self.lock.unlock()
            handler?(outcome)
        }
        beginDeferredMatchIfNeeded()
        return self
    }

    /// Typed verify result — `.mismatched` when server returns `ok: false`.
    public func onVerify(_ handler: @escaping CliqItVerifyHandler) {
        lock.lock()
        verifyHandler = handler
        let cached = lastVerifyOutcome
        lock.unlock()
        if let cached {
            DispatchQueue.main.async { handler(cached) }
        }
    }

    public func onDeferredMatchDebug(_ handler: @escaping CliqItDeferredMatchDebugHandler) {
        lock.lock()
        deferredMatchHandler = handler
        let configured = configuration != nil
        let response = lastDeferredMatchResponse
        lock.unlock()

        guard configured else {
            Self.warnNotConfigured(context: "onDeferredMatchDebug")
            DispatchQueue.main.async { handler(.failure(.notConfigured)) }
            return
        }

        if let response {
            DispatchQueue.main.async { handler(.success(response)) }
        }
    }

    /// - Warning: Deprecated. Use `onLinkReceived` — deferred outcomes arrive there with the same fields
    ///   (`status`, `matched`, `tier`, `score`, `slug`, `destinationPath`, …).
    @available(*, deprecated, message: "Use onLinkReceived — unified payload for direct + deferred")
    public func onDeferredMatch(_ handler: @escaping CliqItDeferredMatchHandler) {
        lock.lock()
        deferredMatchOutcomeHandler = handler
        let configured = configuration != nil
        let response = lastDeferredMatchResponse
        lock.unlock()

        guard configured else {
            Self.warnNotConfigured(context: "onDeferredMatch")
            DispatchQueue.main.async { handler(.failed(.notConfigured)) }
            return
        }

        if let response {
            DispatchQueue.main.async { handler(response.outcome) }
        }
    }

    /// Emits `status: alreadyReported` on `onLinkReceived` when match already ran this install.
    public func notifyAlreadyReportedIfNeeded() {
        guard hasDeferredMatchBeenReported, !isDeferredMatchInFlight else { return }
        lock.lock()
        let config = configuration
        lock.unlock()
        deliver(CliqItDeferredMatchClient.makeAlreadyReportedPayload(configuration: config))
    }

    public func onDeferredMatchDebugRequest(_ handler: @escaping CliqItDeferredMatchDebugRequestHandler) {
        lock.lock()
        deferredMatchRequestHandler = handler
        let json = lastMatchRequestJSON
        lock.unlock()

        if let json {
            DispatchQueue.main.async { handler(json) }
        }
    }

    public func runDeferredMatchDebug(clickSessionId: String? = nil) {
        guard isConfigured else {
            Self.warnNotConfigured(context: "runDeferredMatchDebug")
            lock.lock()
            let outcomeHandler = deferredMatchOutcomeHandler
            let matchHandler = deferredMatchHandler
            lock.unlock()
            if let outcomeHandler {
                DispatchQueue.main.async { outcomeHandler(.failed(.notConfigured)) }
            }
            if let matchHandler {
                DispatchQueue.main.async { matchHandler(.failure(.notConfigured)) }
            }
            return
        }
        performDeferredMatch(
            options: CliqItDeferredMatchOptions(clickSessionId: clickSessionId),
            markReported: false
        )
    }

    /// Direct opens **and** deferred match outcomes (same `CliqItPayload` fields).
    /// Check `status` / `isDeferred` / `shouldNavigate`.
    public func onLinkReceived(_ handler: @escaping CliqItHandler) {
        if !isConfigured {
            Self.warnNotConfigured(context: "onLinkReceived")
        }
        lock.lock()
        self.handler = handler
        lock.unlock()
        deliverPendingPayloadIfNeeded()
    }

    /// - Warning: Deprecated. Use `onLinkReceived`.
    @available(*, deprecated, renamed: "onLinkReceived")
    public func onDeepLink(_ handler: @escaping CliqItHandler) {
        onLinkReceived(handler)
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        captureLaunchClickSessionId(from: url)

        guard let configuration else {
            log("Received URL before configure(): \(url.absoluteString)")
            // Buffer so onLinkReceived can retry after configure if needed.
            lock.lock()
            pendingPayload = CliqItPayload(
                url: url,
                path: url.path.isEmpty ? "/" : url.path,
                pathComponents: url.path.split(separator: "/").map(String.init).filter { !$0.isEmpty },
                queryParameters: Self.queryItems(from: url),
                source: .unknown,
                status: .opened
            )
            lock.unlock()
            return false
        }

        guard let payload = CliqItParser.parse(url: url, configuration: configuration) else {
            log("Ignored unsupported URL: \(url.absoluteString) (host=\(url.host ?? "-") expected=\(configuration.universalLinkDomain ?? "-") scheme=\(configuration.customURLScheme ?? "-"))")
            NotificationCenter.default.post(
                name: .cliqItDeepLinkIgnored,
                object: nil,
                userInfo: ["url": url.absoluteString]
            )
            return false
        }

        receivedDirectDeepLinkThisSession = true

        // Smart-link slug → resolve destination via API, then deliver app path (iosDestination ?? destination).
        if CliqItParser.slug(from: url) != nil {
            fetchDirectLinkDetails(
                for: url,
                fallbackPayload: payload,
                configuration: configuration
            )
            return true
        }

        return deliver(payload)
    }

    /// Fires after each direct-link GET `/api/v1/sdk/link/{slug}`.
    public func onDirectLinkLookup(_ handler: @escaping CliqItDirectLinkLookupHandler) {
        lock.lock()
        directLinkLookupHandler = handler
        let cached = lastDirectLinkDetails
        lock.unlock()
        if let cached {
            DispatchQueue.main.async { handler(.success(cached)) }
        }
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

    public func consumePendingDeepLink() -> CliqItPayload? {
        lock.lock()
        defer { lock.unlock() }
        let payload = pendingPayload
        pendingPayload = nil
        return payload
    }

    @discardableResult
    private func deliver(_ payload: CliqItPayload) -> Bool {
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
            options: CliqItDeferredMatchOptions(clickSessionId: sessionId),
            markReported: true
        )
    }

    private func captureLaunchClickSessionId(from url: URL) {
        guard let sessionId = CliqItParser.parseClickSessionId(from: url) else { return }
        lock.lock()
        if launchClickSessionId == nil {
            launchClickSessionId = sessionId
        }
        lock.unlock()
    }

    /// Direct link only — resolve `{slug}` then deliver `iosDestination ?? destination`.
    private func fetchDirectLinkDetails(
        for url: URL,
        fallbackPayload: CliqItPayload,
        configuration: CliqItConfiguration
    ) {
        guard let slug = CliqItParser.slug(from: url) else {
            _ = deliver(fallbackPayload)
            return
        }

        Task {
            let result = await CliqItLinkLookupClient.fetch(slug: slug, configuration: configuration)

            switch result {
            case .success(let details):
                print("✅ [CliqIt] link lookup OK — path=\(details.resolvedPath ?? "-") slug=\(details.slug ?? slug)")
                lock.lock()
                lastDirectLinkDetails = details
                let handler = directLinkLookupHandler
                lock.unlock()
                if let handler {
                    DispatchQueue.main.async { handler(.success(details)) }
                }

                if let resolved = CliqItLinkLookupClient.makeResolvedPayload(
                    details: details,
                    originalURL: url,
                    source: fallbackPayload.source,
                    queryParameters: fallbackPayload.queryParameters
                ) {
                    _ = deliver(resolved)
                } else {
                    _ = deliver(fallbackPayload)
                }

            case .failure(let error):
                print("❌ [CliqIt] link lookup error: \(error.localizedDescription)")
                lock.lock()
                let handler = directLinkLookupHandler
                lock.unlock()
                if let handler {
                    DispatchQueue.main.async { handler(.failure(error)) }
                }
                _ = deliver(fallbackPayload)
            }
        }
    }

    private func performDeferredMatch(options: CliqItDeferredMatchOptions, markReported: Bool) {
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

        let resolved = CliqItDeferredMatchOptions(
            clickSessionId: options.clickSessionId ?? storedSessionId
        )
        let debugLogging = config.debugLogging

        Task {
            defer {
                lock.lock()
                deferredMatchInFlight = false
                lock.unlock()
            }

            let output = await CliqItDeferredMatchClient.run(
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
                // ponytail: only consume the install attempt on a real match — notMatched must retry next launch
                if markReported, response.matched {
                    UserDefaults.standard.set(true, forKey: Self.deferredMatchReportedKey)
                }

                lock.lock()
                lastDeferredMatchResponse = response
                let matchHandler = deferredMatchHandler
                let outcomeHandler = deferredMatchOutcomeHandler
                lock.unlock()

                log("Deferred match matched=\(response.matched) tier=\(response.tier ?? "-") confidence=\(response.confidence ?? "-")")
                if response.matched {
                    print("✅ [CliqIt] deferred match OK — path=\(response.destinationPath ?? "-") slug=\(response.slug ?? "-")")
                } else {
                    print("✅ [CliqIt] deferred match finished — notMatched score=\(response.score.map { String(format: "%.2f", $0) } ?? "-")")
                }

                if let matchHandler {
                    DispatchQueue.main.async { matchHandler(.success(response)) }
                }
                if let outcomeHandler {
                    DispatchQueue.main.async { outcomeHandler(response.outcome) }
                }

                lock.lock()
                let receivedDirect = receivedDirectDeepLinkThisSession
                let hasPending = pendingPayload != nil
                lock.unlock()
                let alreadyDelivered = UserDefaults.standard.bool(forKey: Self.deferredDeliveredKey)
                let navigate = response.matched
                    && !alreadyDelivered
                    && !receivedDirect
                    && !hasPending

                let payload = CliqItDeferredMatchClient.makeDeferredPayload(
                    response: response,
                    configuration: config,
                    navigate: navigate
                )
                if navigate {
                    UserDefaults.standard.set(true, forKey: Self.deferredDeliveredKey)
                    log("Deferred link: \(payload.url.absoluteString)")
                }
                deliver(payload)

            case .failure(let error):
                let detail = error.localizedDescription ?? "unknown"
                print("❌ [CliqIt] deferred match error: \(detail)")
                log("Deferred match failed: \(detail)")
                lock.lock()
                let matchHandler = deferredMatchHandler
                let outcomeHandler = deferredMatchOutcomeHandler
                lock.unlock()
                if let matchHandler {
                    DispatchQueue.main.async { matchHandler(.failure(error)) }
                }
                if let outcomeHandler {
                    DispatchQueue.main.async { outcomeHandler(.failed(error)) }
                }
                deliver(
                    CliqItDeferredMatchClient.makeDeferredFailedPayload(
                        error: error,
                        configuration: config
                    )
                )
            }
        }
    }

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        CliqItLogger.debug(message, enabled: true)
    }

    /// Always visible in console — misconfiguration should not fail silently.
    private static func warnNotConfigured(context: String) {
        print("⚠️ [CliqIt] \(context): SDK is not configured. Call CliqItSDK.shared.configure(apiKey:) first. Deferred match will not run.")
        assertionFailure("CliqIt: configure(apiKey:) must be called before \(context)")
    }

    private func logDeepLinkPayload(_ payload: CliqItPayload) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }

        print("══════════════════════════════════════")
        print("🔗 [CliqIt] DEEP LINK")
        print("URL:      \(payload.url.absoluteString)")
        print("Path:     \(payload.path)")
        print("Source:   \(payload.source.rawValue)")
        print("Status:   \(payload.status.rawValue)")
        print("Deferred: \(payload.isDeferred ? "YES" : "no")")
        print("══════════════════════════════════════")
    }
}
