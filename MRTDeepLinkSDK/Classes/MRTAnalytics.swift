import Foundation

public final class MRTAnalytics: @unchecked Sendable {
    public static let shared = MRTAnalytics()

    private static let anonymousIdDefaultsKey = "com.mrtdeeplink.analytics.anonymousId"

    private var configuration: MRTAnalyticsConfiguration?
    private var userId: String?
    private var anonymousId: String?
    private let lock = NSLock()

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    public var currentUserId: String? {
        lock.lock()
        defer { lock.unlock() }
        return userId
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

        log("Analytics configured")
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
        log("Anonymous ID set")
    }

    /// Identify the logged-in user for subsequent events.
    public func identify(userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lock.lock()
        self.userId = trimmed
        lock.unlock()

        log("User identified: \(trimmed)")
    }

    /// Clear the identified user (anonymous ID is kept).
    public func resetUser() {
        lock.lock()
        userId = nil
        lock.unlock()

        log("User identity cleared")
    }

    /// Log an event to your platform.
    public func track(
        eventName: String,
        properties: [String: String] = [:]
    ) {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            log("Ignored event — eventName is required")
            return
        }

        lock.lock()
        let configuration = configuration
        let userId = userId
        let anonymousId = resolvedAnonymousId()
        lock.unlock()

        guard let configuration else {
            log("Ignored event — analytics not configured")
            return
        }

        let payload = MRTEventPayload(
            eventName: trimmedName,
            anonymousId: anonymousId,
            userId: userId,
            properties: properties.isEmpty ? nil : properties
        )

        if userId == nil, anonymousId.isEmpty {
            log("Ignored event — anonymousId or userId is required")
            return
        }

        Task {
            let result = await MRTEventClient.send(event: payload, configuration: configuration)
            switch result {
            case .success:
                log("Event tracked: \(trimmedName)")
            case .failure(let message):
                print("[MRTDeepLinkSDK] Event tracking failed: \(message)")
            }
        }
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

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        print("[MRTDeepLinkSDK] \(message)")
    }
}
