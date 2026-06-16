#if canImport(UIKit)
import Foundation
import UIKit

typealias MRTSessionEventHandler = (_ eventName: String, _ properties: [String: String]) -> Void

final class MRTSessionTracker: @unchecked Sendable {
    private static let sessionIdKey = "com.mrtdeeplink.analytics.sessionId"
    private static let sessionStartedAtKey = "com.mrtdeeplink.analytics.sessionStartedAt"
    private static let lastBackgroundAtKey = "com.mrtdeeplink.analytics.lastBackgroundAt"

    private let lock = NSLock()
    private var sessionId: String?
    private var sessionStartedAt: Date?
    private var sessionTimeout: TimeInterval = MRTDeepLinkDefaults.sessionTimeout
    private var eventHandler: MRTSessionEventHandler?
    private var lifecycleObservations: [NSObjectProtocol] = []
    private var isMonitoring = false

    func start(
        sessionTimeout: TimeInterval = MRTDeepLinkDefaults.sessionTimeout,
        eventHandler: @escaping MRTSessionEventHandler
    ) {
        lock.lock()
        self.sessionTimeout = sessionTimeout
        self.eventHandler = eventHandler
        lock.unlock()

        registerLifecycleObserversIfNeeded()
        restorePersistedSessionIfNeeded()
        handleAppDidBecomeActive()
    }

    func currentSessionId() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return sessionId
    }

    func handleAppDidBecomeActive() {
        let shouldStartNewSession = lock.withLock { () -> Bool in
            if hasSessionTimedOut() {
                clearPersistedSession()
                return true
            }

            if let sessionId, !sessionId.isEmpty {
                return false
            }

            return restorePersistedSessionIfNeeded() == false
        }

        if shouldStartNewSession {
            startNewSession()
        }
    }

    func handleAppDidEnterBackground() {
        let snapshot = lock.withLock { () -> (sessionId: String, duration: TimeInterval)? in
            guard let sessionId, let sessionStartedAt else { return nil }

            let duration = Date().timeIntervalSince(sessionStartedAt)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastBackgroundAtKey)
            persistSession(sessionId: sessionId, startedAt: sessionStartedAt)
            return (sessionId, duration)
        }

        guard let snapshot else { return }

        emit(
            eventName: "session_ended",
            properties: [
                "sessionId": snapshot.sessionId,
                "durationSeconds": String(format: "%.0f", snapshot.duration)
            ]
        )
    }

    @discardableResult
    private func restorePersistedSessionIfNeeded() -> Bool {
        guard let storedSessionId = UserDefaults.standard.string(forKey: Self.sessionIdKey),
              !storedSessionId.isEmpty else {
            return false
        }

        let startedAtTimestamp = UserDefaults.standard.double(forKey: Self.sessionStartedAtKey)
        guard startedAtTimestamp > 0 else { return false }

        sessionId = storedSessionId
        sessionStartedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        return true
    }

    private func startNewSession() {
        let newSessionId = "sess_\(UUID().uuidString.lowercased())"
        let startedAt = Date()

        lock.lock()
        sessionId = newSessionId
        sessionStartedAt = startedAt
        lock.unlock()

        persistSession(sessionId: newSessionId, startedAt: startedAt)
        UserDefaults.standard.removeObject(forKey: Self.lastBackgroundAtKey)

        emit(
            eventName: "session_started",
            properties: [
                "sessionId": newSessionId,
                "timestamp": ISO8601DateFormatter().string(from: startedAt)
            ]
        )
    }

    private func persistSession(sessionId: String, startedAt: Date) {
        UserDefaults.standard.set(sessionId, forKey: Self.sessionIdKey)
        UserDefaults.standard.set(startedAt.timeIntervalSince1970, forKey: Self.sessionStartedAtKey)
    }

    private func clearPersistedSession() {
        sessionId = nil
        sessionStartedAt = nil
        UserDefaults.standard.removeObject(forKey: Self.sessionIdKey)
        UserDefaults.standard.removeObject(forKey: Self.sessionStartedAtKey)
    }

    private func hasSessionTimedOut() -> Bool {
        guard let lastBackground = storedLastBackgroundDate() else { return false }
        return Date().timeIntervalSince(lastBackground) >= sessionTimeout
    }

    private func storedLastBackgroundDate() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: Self.lastBackgroundAtKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func emit(eventName: String, properties: [String: String]) {
        lock.lock()
        let handler = eventHandler
        lock.unlock()
        handler?(eventName, properties)
    }

    private func registerLifecycleObserversIfNeeded() {
        lock.lock()
        let alreadyMonitoring = isMonitoring
        lock.unlock()
        guard !alreadyMonitoring else { return }

        let center = NotificationCenter.default

        let activeObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidBecomeActive()
        }

        let backgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppDidEnterBackground()
        }

        lock.lock()
        lifecycleObservations = [activeObserver, backgroundObserver]
        isMonitoring = true
        lock.unlock()
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

#endif
