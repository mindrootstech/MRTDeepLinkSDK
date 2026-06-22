import Foundation

enum MRTSDKLogger {
    static func debug(_ message: String, enabled: Bool) {
        guard enabled else { return }
        print("[MRTDeepLinkSDK] \(message)")
    }
}
