import Combine
import SwiftUI
import MRTDeepLinkSDK

@main
struct MRTDeepLinkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = AppDeepLinkRouter()

    init() {
        MRTDeepLink.shared.configure(
            apiKey: AppConfig.sdkAPIKey,
            debugLogging: true,
            serverURL: URL(string: AppConfig.serverURL)!,
            universalLinkDomain: AppConfig.universalLinkDomain,
            customURLScheme: AppConfig.customURLScheme
        )
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(router)
                .handleMRTDeepLinks { payload in
                    router.handle(payload)
                }
        }
    }
}

private struct RootTabView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "link")
                }
                .tag(AppTab.home)

            ProductListView()
                .tabItem {
                    Label("Products", systemImage: "bag.fill")
                }
                .tag(AppTab.products)
        }
    }
}

enum AppTab: Hashable {
    case home
    case products
}

final class AppDeepLinkRouter: ObservableObject {
    @Published var destination: DeepLinkDestination?
    @Published var lastPayload: MRTDeepLinkPayload?
    @Published var selectedTab: AppTab = .home
    @Published var pendingProductID: Int?

    func handle(_ payload: MRTDeepLinkPayload) {
        lastPayload = payload
        printDeepLinkPayload(payload)

        if let productID = Self.parseProductID(from: payload) {
            selectedTab = .products
            pendingProductID = productID
        }
    }

    private static func parseProductID(from payload: MRTDeepLinkPayload) -> Int? {
        let components = payload.pathComponents
        guard let productIndex = components.firstIndex(of: "product"),
              productIndex + 1 < components.count,
              let id = Int(components[productIndex + 1]) else {
            return nil
        }
        return id
    }

    func clearPendingProduct() {
        pendingProductID = nil
    }

    private func printDeepLinkPayload(_ payload: MRTDeepLinkPayload) {
        print("══════════════════════════════════════")
        print("🔗 DEEP LINK RECEIVED")
        print("URL:      \(payload.url.absoluteString)")
        print("Path:     \(payload.path)")
        print("Source:   \(payload.source.rawValue)")
        print("Deferred: \(payload.isDeferred ? "YES ✅" : "no")")
        print("══════════════════════════════════════")
    }
}

enum DeepLinkDestination: Equatable {
    case home
    case product(id: String)
    case profile(userId: String)
}
