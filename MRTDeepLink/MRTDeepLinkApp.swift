import Combine
import SwiftUI
import CliqIt

@main
struct MRTDeepLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppDeepLinkRouter()

    init() {
        CliqItSDK.shared.configure(apiKey: AppConfig.sdkAPIKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .handleCliqItDeepLinks { payload in
                    router.handle(payload)
                }
                .onReceive(NotificationCenter.default.publisher(for: .cliqItDeepLinkIgnored)) { note in
                    if let url = note.userInfo?["url"] as? String {
                        router.lastIgnoredURL = url
                    }
                }
        }
    }
}

final class AppDeepLinkRouter: ObservableObject {
    @Published var lastPayload: CliqItPayload?
    @Published var lastIgnoredURL: String?

    func handle(_ payload: CliqItPayload) {
        lastPayload = payload
        lastIgnoredURL = nil
        print("══════════════════════════════════════")
        print("🔗 DEEP LINK RECEIVED")
        print("URL:      \(payload.url.absoluteString)")
        print("Path:     \(payload.path)")
        print("Segments: \(payload.pathComponents.joined(separator: " → "))")
        print("Source:   \(payload.source.rawValue)")
        print("Deferred: \(payload.isDeferred ? "YES ✅" : "no")")
        if payload.queryParameters.isEmpty {
            print("Params:   (none)")
        } else {
            print("Params:")
            for key in payload.queryParameters.keys.sorted() {
                print("  • \(key) = \(payload.queryParameters[key] ?? "")")
            }
        }
        print("══════════════════════════════════════")
    }

    func noteIgnoredURL(_ url: URL) {
        lastIgnoredURL = url.absoluteString
        print("⚠️ Ignored deep link (domain/scheme mismatch): \(url.absoluteString)")
    }
}
