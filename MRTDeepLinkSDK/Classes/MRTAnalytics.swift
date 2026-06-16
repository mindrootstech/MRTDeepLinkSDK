import Foundation

public final class MRTAnalytics: @unchecked Sendable {
    public static let shared = MRTAnalytics()

    private static let anonymousIdDefaultsKey = "com.mrtdeeplink.analytics.anonymousId"
    private static let userIdDefaultsKey = "com.mrtdeeplink.analytics.userId"

    private var configuration: MRTAnalyticsConfiguration?
    private var identifiedUserId: String?
    private var anonymousId: String?
    private var generatedUserId: String?
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
        return resolvedUserId(explicit: nil)
    }

    public var currentAnonymousId: String {
        lock.lock()
        defer { lock.unlock() }
        return resolvedAnonymousId()
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
        lock.unlock()

        log("Analytics configured — userId: \(currentUserId), anonymousId: \(currentAnonymousId)")
        return self
    }

    /// Assign a known anonymous ID (otherwise one is generated and persisted).
    public func setAnonymousId(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        anonymousId = trimmed
        lock.unlock()

        UserDefaults.standard.set(trimmed, forKey: Self.anonymousIdDefaultsKey)
        log("Anonymous ID set: \(trimmed)")
    }

    /// Identify the logged-in user for subsequent events.
    public func identify(userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        identifiedUserId = trimmed
        lock.unlock()

        log("User identified: \(trimmed)")
    }

    /// Clear the identified user (auto-generated userId is kept).
    public func resetUser() {
        lock.lock()
        identifiedUserId = nil
        lock.unlock()

        log("User identity cleared — using auto userId: \(currentUserId)")
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
        let resolvedUserId = resolvedUserId(explicit: userId)
        let anonymousId = resolvedAnonymousId()
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
            case .failure(let message):
                logEvent("Event logging failed: \(message)")
            }
        }
    }

    private func resolvedUserId(explicit: String?) -> String {
        if let explicit {
            let trimmed = explicit.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        if let identifiedUserId, !identifiedUserId.isEmpty {
            return identifiedUserId
        }

        if let generatedUserId, !generatedUserId.isEmpty {
            return generatedUserId
        }

        if let stored = UserDefaults.standard.string(forKey: Self.userIdDefaultsKey),
           !stored.isEmpty {
            generatedUserId = stored
            return stored
        }

        let generated = "user_\(UUID().uuidString.lowercased())"
        generatedUserId = generated
        UserDefaults.standard.set(generated, forKey: Self.userIdDefaultsKey)
        return generated
    }

    private func resolvedAnonymousId() -> String {
        if let anonymousId, !anonymousId.isEmpty {
            return anonymousId
        }

        if let stored = UserDefaults.standard.string(forKey: Self.anonymousIdDefaultsKey),
           !stored.isEmpty {
            anonymousId = stored
            return stored
        }

        let generated = "anon_\(UUID().uuidString.lowercased())"
        anonymousId = generated
        UserDefaults.standard.set(generated, forKey: Self.anonymousIdDefaultsKey)
        return generated
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
