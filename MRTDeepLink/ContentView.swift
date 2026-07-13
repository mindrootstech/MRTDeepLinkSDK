import SwiftUI
import MRTDeepLinkSDK

struct ContentView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter
    @State private var clickSessionId = AppConfig.defaultClickSessionId
    @State private var matchResponse: MRTDeferredMatchResponse?
    @State private var matchRequestJSON: String?
    @State private var matchError: String?
    @State private var isMatchLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("Deferred Deep Link")
                        .font(.title2.bold())

                    deferredMatchView

                    if let payload = router.lastPayload {
                        deepLinkDebugView(payload)
                    }

                    testLinksView
                    configView
                }
                .padding()
            }
            .navigationTitle("Deep Link")
            .onAppear {
                MRTDeepLink.shared.onDeferredMatchDebugRequest { json in
                    matchRequestJSON = json
                }
                MRTDeepLink.shared.onDeferredMatchDebug { result in
                    isMatchLoading = false
                    switch result {
                    case .success(let response):
                        matchResponse = response
                        matchError = nil
                    case .failure(let error):
                        matchError = error.localizedDescription
                    }
                }
                if let cached = MRTDeepLink.shared.currentDeferredMatchDebugResponse {
                    matchResponse = cached
                }
                if let json = MRTDeepLink.shared.currentMatchDebugRequestJSON {
                    matchRequestJSON = json
                }
            }
        }
    }

    private var deferredMatchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deferred Match")
                .font(.headline)

            Text("POST /api/deferred/app/match")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            TextField("clickSessionId", text: $clickSessionId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption.monospaced())

            Button(isMatchLoading ? "Running…" : "Run deferred match") {
                runMatch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isMatchLoading)

            if isMatchLoading {
                ProgressView("Calling /api/deferred/app/match…")
                    .font(.caption)
            }

            if let matchError {
                Text(matchError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if let matchRequestJSON {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Request body")
                        .font(.subheadline.bold())
                    Text(prettyJSONString(matchRequestJSON) ?? matchRequestJSON)
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let matchResponse {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Response")
                        .font(.subheadline.bold())
                    debugRow("matched", matchResponse.matched ? "true" : "false")
                    debugRow("tier", matchResponse.tier ?? "—")
                    debugRow("confidence", matchResponse.confidence ?? "—")
                    debugRow("score", matchResponse.score.map { String(format: "%.2f", $0) } ?? "—")
                    debugRow("destinationPath", matchResponse.destinationPath ?? "—")
                    debugRow("slug", matchResponse.slug ?? "—")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func runMatch() {
        isMatchLoading = true
        matchError = nil
        matchRequestJSON = nil
        let sessionId = clickSessionId.trimmingCharacters(in: .whitespacesAndNewlines)
        MRTDeepLink.shared.runDeferredMatchDebug(
            clickSessionId: sessionId.isEmpty ? nil : sessionId
        )
    }

    private func prettyJSONString(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return string
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

    private func deepLinkDebugView(_ payload: MRTDeepLinkPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Deep Link")
                    .font(.headline)
                if payload.isDeferred {
                    Text("DEFERRED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            debugRow("URL", payload.url.absoluteString)
            debugRow("Path", payload.path)
            debugRow("Source", payload.source.rawValue)
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
