import SwiftUI
import CliqIt

struct ContentView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("onLinkReceived")
                        .font(.title2.bold())

                    Text("Only public callback — verify, slug lookup, and deferred match run in the background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let payload = router.lastPayload {
                        deepLinkDebugView(payload)
                    } else if let ignored = router.lastIgnoredURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Link ignored")
                                .font(.headline)
                            Text(ignored)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text("Check Associated Domains entitlements match the link host.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("Waiting for onLinkReceived…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    testLinksView
                    configView
                }
                .padding()
            }
            .navigationTitle("CliqIt")
        }
    }

    private var testLinksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test link")
                .font(.headline)

            if let url = URL(string: AppConfig.sampleSmartLinkURL) {
                shareLinkRow(title: "Short link", url: url)
            }

            if let url = AppConfig.customSchemeTestURL {
                shareLinkRow(title: "Custom scheme", url: url)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var configView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Config")
                .font(.headline)
            Text("Universal link: \(AppConfig.universalLinkDomain)")
            Text("API: \(AppConfig.serverURL)")
            Text("Scheme: \(AppConfig.customURLScheme)://")
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deepLinkDebugView(_ payload: CliqItPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payload.isDeferred ? "Deferred" : "Direct")
                    .font(.headline)
                Text(payload.status.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }

            debugRow("URL", payload.url.absoluteString)
            debugRow("Path", payload.path)
            debugRow("Status", payload.status.rawValue)
            debugRow("Source", payload.source.rawValue)
            debugRow("Deferred", payload.isDeferred ? "YES" : "no")
            debugRow("shouldNavigate", payload.shouldNavigate ? "YES" : "no")
            if let matched = payload.matched {
                debugRow("matched", matched ? "true" : "false")
            }
            if let slug = payload.slug { debugRow("slug", slug) }
            if let tier = payload.tier { debugRow("tier", tier) }
            if let score = payload.score {
                debugRow("score", String(format: "%.2f", score))
            }
            if let err = payload.errorMessage {
                debugRow("Error", err)
            }

            if !payload.pathComponents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path segments")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(Array(payload.pathComponents.enumerated()), id: \.offset) { index, segment in
                        Text("[\(index)] \(segment)")
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Parameters")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if payload.queryParameters.isEmpty {
                    Text("(none)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(payload.queryParameters.keys.sorted(), id: \.self) { key in
                        debugRow(key, payload.queryParameters[key] ?? "")
                    }
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
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
                Label("Share", systemImage: "square.and.arrow.up")
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
