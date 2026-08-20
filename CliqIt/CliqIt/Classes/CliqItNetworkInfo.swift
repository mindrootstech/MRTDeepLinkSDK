import Foundation
import Network

enum CliqItNetworkInfo {
    /// Returns `wifi` | `cellular` | `none`.
    /// Waits briefly for a stable path — first NWPathMonitor callback is often unsatisfied.
    static func connectionType() async -> String? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.cliqit.network")
            var resumed = false

            func finish(with path: NWPath) {
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: map(path))
            }

            monitor.pathUpdateHandler = { path in
                // Prefer a usable interface as soon as it appears; don't settle on early "none".
                if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.cellular) {
                    finish(with: path)
                }
            }

            monitor.start(queue: queue)

            // Settle after a short window using currentPath (fixes race → "none" on wifi).
            queue.asyncAfter(deadline: .now() + 0.25) {
                finish(with: monitor.currentPath)
            }
        }
    }

    private static func map(_ path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "wifi"
        }
        if path.usesInterfaceType(.cellular) {
            return "cellular"
        }
        // Satisfied but not classified — check available interfaces
        if path.status == .satisfied {
            for interface in path.availableInterfaces {
                switch interface.type {
                case .wifi: return "wifi"
                case .cellular: return "cellular"
                default: break
                }
            }
        }
        return "none"
    }
}
