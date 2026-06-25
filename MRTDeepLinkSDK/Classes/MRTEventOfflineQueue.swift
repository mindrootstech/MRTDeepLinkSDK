import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum MRTEventOfflineQueue {
    private static let storageKey = "com.mrtdeeplink.events.offlineQueue"
    private static let lock = NSLock()
    private static var isMonitoringLifecycle = false

    static func enqueue(_ event: MRTEventPayload) {
        lock.lock()
        defer { lock.unlock() }

        var queue = loadQueue()
        queue.append(event)

        let limit = MRTDeepLinkDefaults.offlineEventQueueLimit
        if queue.count > limit {
            queue.removeFirst(queue.count - limit)
        }

        saveQueue(queue)
    }

    static func pendingCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return loadQueue().count
    }

    static func startMonitoring(flushHandler: @escaping @Sendable () -> Void) {
        #if canImport(UIKit)
        lock.lock()
        let shouldRegister = !isMonitoringLifecycle
        isMonitoringLifecycle = true
        lock.unlock()

        guard shouldRegister else { return }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            flushHandler()
        }
        #else
        _ = flushHandler
        #endif
    }

    static func flush(
        configuration: MRTAnalyticsConfiguration,
        debugLogging: Bool,
        log: @escaping (String) -> Void
    ) async {
        let events: [MRTEventPayload]
        lock.lock()
        events = loadQueue()
        lock.unlock()

        guard !events.isEmpty else { return }

        log("Flushing \(events.count) queued event(s)")

        var remaining: [MRTEventPayload] = []
        for event in events {
            let result = await MRTEventClient.send(
                event: event,
                configuration: configuration,
                debugLogging: debugLogging
            )
            switch result {
            case .success:
                log("Queued event sent: \(event.eventName)")
            case .failure(let error):
                switch error {
                case .message(let text):
                    log("Queued event failed: \(text)")
                }
                remaining.append(event)
            }
        }

        lock.lock()
        saveQueue(remaining)
        lock.unlock()

        if !remaining.isEmpty {
            log("\(remaining.count) event(s) remain in offline queue")
        }
    }

    private static func loadQueue() -> [MRTEventPayload] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([MRTEventPayload].self, from: data)) ?? []
    }

    private static func saveQueue(_ queue: [MRTEventPayload]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
