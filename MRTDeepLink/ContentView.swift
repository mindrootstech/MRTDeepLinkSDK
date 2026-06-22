import SwiftUI
import MRTDeepLinkSDK

enum SmartLinkConfig {
    static let configuration = MRTSmartLinkConfiguration(
        webDomain: "glennis-pseudosyphilitic-maude.ngrok-free.dev",
        customURLScheme: "mrtdeeplink",
        iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id0000000000")!
    )

    static let sampleProductLink = MRTSmartLinkBuilder.makeWebURL(
        path: "/notifytest/product/42",
        queryItems: [URLQueryItem(name: "id", value: "abc")],
        configuration: configuration
    )!

    static let sampleProfileLink = MRTSmartLinkBuilder.makeWebURL(
        path: "/notifytest/profile/99",
        configuration: configuration
    )!
}

struct ContentView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter
    @State private var lastTrackedEvent: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("MRTDeepLinkSDK Demo")
                        .font(.title2.bold())

                    licenseStatusView

                    destinationView

                    analyticsSection

                    if let payload = router.lastPayload {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Deep Link")
                                .font(.headline)
                            Text("URL: \(payload.url.absoluteString)")
                                .font(.caption)
                            Text("Path: \(payload.path)")
                                .font(.caption)
                            Text("Source: \(payload.source.rawValue)")
                                .font(.caption)
                            if payload.isDeferred {
                                Text("Deferred: yes")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.quaternary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Smart Links (WhatsApp / SMS / Email)")
                            .font(.headline)

                        shareLinkRow(title: "Product", url: SmartLinkConfig.sampleProductLink)
                        shareLinkRow(title: "Profile", url: SmartLinkConfig.sampleProfileLink)

                        Text("App installed → app opens\nApp not installed → App Store")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Direct scheme (sirf testing)")
                            .font(.headline)
                        Text("mrtdeeplink://product/42?id=abc")
                        Text("mrtdeeplink://profile/99")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Deep Link")
            .onAppear {
                trackEvent(
                    name: "screen_view",
                    properties: ["screen": "Home"]
                )
            }
        }
    }

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Event Analytics")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("userId: \(MRTAnalytics.shared.currentUserId)")
                Text("anonymousId: \(MRTAnalytics.shared.currentAnonymousId)")
                if let loginUserId = MRTAnalytics.shared.currentLoginUserId {
                    Text("loginUserId: \(loginUserId)")
                }
                if let sessionId = MRTAnalytics.shared.currentSessionId {
                    Text("sessionId: \(sessionId)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            if let lastTrackedEvent {
                Text("Last event: \(lastTrackedEvent)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button {
                trackEvent(
                    name: "button_click",
                    properties: [
                        "buttonName": "Submit",
                        "screen": "Home"
                    ]
                )
            } label: {
                Label("Trigger button_click", systemImage: "hand.tap.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                MRTAnalytics.shared.identify(userId: "user_98765")
                trackEvent(
                    name: "user_identified",
                    properties: ["source": "demo_button"]
                )
            } label: {
                Label("Identify user + track event", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("Check Xcode console for API logs on every trigger.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func trackEvent(
        name: String,
        properties: [String: String] = [:]
    ) {
        MRTAnalytics.shared.track(
            eventName: name,
            properties: properties
        )
        lastTrackedEvent = name
    }

    @ViewBuilder
    private var licenseStatusView: some View {
        switch router.licenseStatus {
        case .idle, .validating:
            Label("Checking license…", systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .valid:
            Label("License active", systemImage: "checkmark.seal.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .invalid(let message):
            VStack(spacing: 4) {
                Label("License invalid", systemImage: "xmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch router.destination {
        case .none, .home:
            Text("Home Screen")
                .foregroundStyle(.secondary)
        case .product(let id):
            Label("Product #\(id)", systemImage: "bag.fill")
                .font(.title3)
        case .profile(let userId):
            Label("Profile \(userId)", systemImage: "person.fill")
                .font(.title3)
        }
    }

    private func shareLinkRow(title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
            Text(url.absoluteString)
                .font(.caption2)
                .textSelection(.enabled)
            ShareLink(item: url) {
                Label("Share \(title) Link", systemImage: "square.and.arrow.up")
            }
            .font(.caption)
        }
        .padding(10)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppDeepLinkRouter())
}
