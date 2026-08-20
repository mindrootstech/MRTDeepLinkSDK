import Foundation

enum CliqItLogger {
    static func debug(_ message: String, enabled: Bool) {
        guard enabled else { return }
        print("[CliqIt] \(message)")
    }
}
