import Foundation

public final class MRTAnalytics: @unchecked Sendable {
    public static let shared = MRTAnalytics()

    private static let anonymousIdDefaultsKey = "com.mrtdeeplink.analytics.anonymousId"
    private static let userIdDefaultsKey = "com.mrtdeeplink.analytics.userId"
    private static let loginUserIdDefaultsKey = "com.mrtdeeplink.analytics.loginUserId"

    private var configuration: MRTAnalyticsConfiguration?
    private let lock = NSLock()

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    /// Stable SDK user ID — generated once per app install, never changes.
    public var currentUserId: String {
        lock.lock()
        defer { lock.unlock() }
        return ensureUserId()
    }

    /// Stable anonymous ID — generated once per app install, never changes.
    public var currentAnonymousId: String {
        lock.lock()
        defer { lock.unlock() }
        return ensureAnonymousId()
    }

    /// Logged-in user ID from `identify(userId:)` — separate from device `userId`.
    public var currentLoginUserId: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedValue(forKey: Self.loginUserIdDefaultsKey)
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
        persist(trimmed, forKey: Self.anonymousIdDefaultsKey)
        lock.unlock()

        log("Anonymous ID set: \(trimmed)")
    }

    /// Link a logged-in user without changing the stable device `userId`.
    public func identify(userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        persist(trimmed, forKey: Self.loginUserIdDefaultsKey)
        lock.unlock()

        log("Login user linked: \(trimmed) (device userId unchanged: \(currentUserId))")
    }

    /// Clear the linked logged-in user.
    public func resetUser() {
        lock.lock()
        UserDefaults.standard.removeObject(forKey: Self.loginUserIdDefaultsKey)
        lock.unlock()

        log("Login user cleared — device userId: \(currentUserId)")
    }

    /// Log an event to your platform.
    public func track(
        eventName: String,
        properties: [String: String] = [:]
    ) {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            logEvent("Ignored event — eventName is required")
            return
        }

        lock.lock()
        let configuration = configuration
        let userId = ensureUserId()
        let anonymousId = ensureAnonymousId()
        let loginUserId = storedValue(forKey: Self.loginUserIdDefaultsKey)
        lock.unlock()

        guard let configuration else {
            logEvent("Ignored event — analytics not configured")
            return
        }

        let payload = MRTEventPayload(
            eventName: trimmedName,
            anonymousId: anonymousId,
            userId: userId,
            loginUserId: loginUserId,
            properties: properties.isEmpty ? nil : properties
        )

        var logMessage = "Event triggered: \(trimmedName) | userId: \(userId) | anonymousId: \(anonymousId)"
        if let loginUserId {
            logMessage += " | loginUserId: \(loginUserId)"
        }
        logEvent(logMessage)

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

    private func ensureUserId() -> String {
        if let stored = storedValue(forKey: Self.userIdDefaultsKey) {
            return stored
        }

        let generated = "user_\(UUID().uuidString.lowercased())"
        persist(generated, forKey: Self.userIdDefaultsKey)
        return generated
    }

    private func ensureAnonymousId() -> String {
        if let stored = storedValue(forKey: Self.anonymousIdDefaultsKey) {
            return stored
        }

        let generated = "anon_\(UUID().uuidString.lowercased())"
        persist(generated, forKey: Self.anonymousIdDefaultsKey)
        return generated
    }

    private func persist(_ value: String, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
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
