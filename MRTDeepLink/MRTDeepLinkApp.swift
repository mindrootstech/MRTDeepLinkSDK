import Combine
import SwiftUI
import MRTDeepLinkSDK

@main
struct MRTDeepLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppDeepLinkRouter()

    init() {
        MRTDeepLink.shared.configure(
            apiKey: "dlh_sdk_bf5a418781645414bb0cb0dbbe4eb981",
            debugLogging: true
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .onAppear {
                    MRTDeepLink.shared.onLicenseStatusChange { status in
                        router.updateLicenseStatus(status)
                    }
                }
                .handleMRTDeepLinks { payload in
                    router.handle(payload)
                }
        }
    }
}

final class AppDeepLinkRouter: ObservableObject {
    @Published var destination: DeepLinkDestination?
    @Published var lastPayload: MRTDeepLinkPayload?
    @Published var licenseStatus: MRTDeepLinkLicenseStatus = .idle

    func updateLicenseStatus(_ status: MRTDeepLinkLicenseStatus) {
        licenseStatus = status
    }

    func handle(_ payload: MRTDeepLinkPayload) {
        lastPayload = payload

        MRTAnalytics.shared.track(
            eventName: "deep_link_opened",
            properties: [
                "url": payload.url.absoluteString,
                "path": payload.path,
                "source": payload.source.rawValue
            ]
        )

        let components = Self.routeComponents(from: payload.pathComponents)
        guard let route = components.first else {
            destination = .home
            return
        }

        switch route {
        case "product":
            let id = components.dropFirst().first ?? payload[query: "id"]
            destination = .product(id: id ?? "unknown")
        case "profile":
            let userId = components.dropFirst().first ?? payload[query: "userId"]
            destination = .profile(userId: userId ?? "unknown")
        default:
            destination = .home
        }
    }

    /// Skips known URL prefixes such as `admin-smartlink`.
    private static func routeComponents(from pathComponents: [String]) -> [String] {
        var components = pathComponents
        if components.first == "admin-smartlink" {
            components.removeFirst()
        }
        if components.first == "notifytest" {
            components.removeFirst()
        }
        return components
    }
}

enum DeepLinkDestination: Equatable {
    case home
    case product(id: String)
    case profile(userId: String)
}
