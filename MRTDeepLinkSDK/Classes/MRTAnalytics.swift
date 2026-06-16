import Foundation

public final class MRTAnalytics: @unchecked Sendable {
    public static let shared = MRTAnalytics()

    private static let anonymousIdDefaultsKey = "com.mrtdeeplink.analytics.anonymousId"
    private static let userIdDefaultsKey = "com.mrtdeeplink.analytics.userId"
    private static let autoUserIdDefaultsKey = "com.mrtdeeplink.analytics.autoUserId"

    private var configuration: MRTAnalyticsConfiguration?
    private let lock = NSLock()

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    public var currentUserId: String {
        lock.lock()
        defer { lock.unlock() }
        return ensureUserId()
    }

    public var currentAnonymousId: String {
        lock.lock()
        defer { lock.unlock() }
        return ensureAnonymousId()
    }

    /// Configure event logging with your platform API key.
    @discardableResult
    public func configure(
        apiKey: String,
        debugLogging: Bool = false,
        serverURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        eventsPath: String = MRTDeepLinkDefaults.eventsPath
    ) -> MRTAnalytics {
        lock.lock()
        configuration = MRTAnalyticsConfiguration(
            apiKey: apiKey,
            debugLogging: debugLogging,
            serverURL: serverURL,
            eventsPath: eventsPath
        )
        let userId = ensureUserId()
        let anonymousId = ensureAnonymousId()
        lock.unlock()

        log("Analytics configured — userId: \(userId), anonymousId: \(anonymousId)")
        return self
    }

    /// Assign a known anonymous ID (otherwise one is generated once and persisted).
    public func setAnonymousId(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        persistAnonymousId(trimmed)
        lock.unlock()

        log("Anonymous ID set: \(trimmed)")
    }

    /// Identify the logged-in user for subsequent events (persisted until app uninstall).
    public func identify(userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        persistUserId(trimmed)
        lock.unlock()

        log("User identified: \(trimmed)")
    }

    /// Restore the auto-generated userId after `identify(userId:)`.
    public func resetUser() {
        lock.lock()
        if let autoUserId = storedValue(forKey: Self.autoUserIdDefaultsKey) {
            persistUserId(autoUserId)
        }
        lock.unlock()

        log("User identity reset — userId: \(currentUserId)")
    }

    /// Log an event to your platform.
    public func track(
        eventName: String,
        userId: String? = nil,
        properties: [String: String] = [:]
    ) {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            logEvent("Ignored event — eventName is required")
            return
        }

        lock.lock()
        let configuration = configuration
        let resolvedUserId = userIdForEvent(explicit: userId)
        let anonymousId = ensureAnonymousId()
        lock.unlock()

        guard let configuration else {
            logEvent("Ignored event — analytics not configured")
            return
        }

        let payload = MRTEventPayload(
            eventName: trimmedName,
            anonymousId: anonymousId,
            userId: resolvedUserId,
            properties: properties.isEmpty ? nil : properties
        )

        logEvent(
            "Event triggered: \(trimmedName) | userId: \(resolvedUserId) | anonymousId: \(anonymousId)"
        )

        if let properties = payload.properties, !properties.isEmpty {
            logEvent("Event properties: \(properties)")
        }

        Task {
            let result = await MRTEventClient.send(event: payload, configuration: configuration)
            switch result {
            case .success:
                logEvent("Event logged: \(trimmedName)")
            case .failure(let error):
                switch error {
                case .message(let text):
                    logEvent("Event logging failed: \(text)")
                }
            }
        }
    }

    private func userIdForEvent(explicit: String?) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ensureUserId()
    }

    private func ensureUserId() -> String {
        if let stored = storedValue(forKey: Self.userIdDefaultsKey) {
            return stored
        }

        let generated = "user_\(UUID().uuidString.lowercased())"
        persistUserId(generated)
        UserDefaults.standard.set(generated, forKey: Self.autoUserIdDefaultsKey)
        return generated
    }

    private func ensureAnonymousId() -> String {
        if let stored = storedValue(forKey: Self.anonymousIdDefaultsKey) {
            return stored
        }

        let generated = "anon_\(UUID().uuidString.lowercased())"
        persistAnonymousId(generated)
        return generated
    }

    private func persistUserId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.userIdDefaultsKey)
    }

    private func persistAnonymousId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.anonymousIdDefaultsKey)
    }

    private func storedValue(forKey key: String) -> String? {
        guard let value = UserDefaults.standard.string(forKey: key),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func logEvent(_ message: String) {
        print("[MRTDeepLinkSDK] \(message)")
    }

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        logEvent(message)
    }
}
