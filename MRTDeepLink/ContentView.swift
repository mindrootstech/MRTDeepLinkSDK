import SwiftUI
import CliqIt

struct ContentView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter
    @State private var clickSessionId = AppConfig.defaultClickSessionId
    @State private var matchResponse: CliqItDeferredMatchResponse?
    @State private var matchRequestJSON: String?
    @State private var matchError: String?
    @State private var isMatchLoading = false
    @State private var webFingerprint: CliqItWebFingerprint?
    @State private var combinedFingerprint: CliqItCombinedFingerprint?
    @State private var isCollectingFingerprint = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("Deferred Deep Link")
                        .font(.title2.bold())

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
                    }

                    webFingerprintView
                    deferredMatchView

                    testLinksView
                    configView
                }
                .padding()
            }
            .navigationTitle("Deep Link")
            .overlay {
                if isMatchLoading {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Matching deferred link…")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .onAppear {
                CliqItSDK.shared.onDeferredMatchDebugRequest { json in
                    isMatchLoading = true
                    matchRequestJSON = json
                    webFingerprint = CliqItSDK.shared.currentWebFingerprint
                    combinedFingerprint = CliqItSDK.shared.combinedFingerprint
                }
                CliqItSDK.shared.onDirectLinkLookup { result in
                    switch result {
                    case .success(let details):
                        print("Demo link lookup → path=\(details[.resolvedPath] ?? "-") slug=\(details[.slug] ?? "-")")
                    case .failure(let error):
                        print("Demo link lookup error: \(error.localizedDescription)")
                    }
                }
                CliqItSDK.shared.onDeferredMatchDebug { result in
                    isMatchLoading = false
                    webFingerprint = CliqItSDK.shared.currentWebFingerprint
                    combinedFingerprint = CliqItSDK.shared.combinedFingerprint
                    switch result {
                    case .success(let response):
                        matchResponse = response
                        matchError = nil
                        // Typed access — no string hunting / print-check needed:
                        // response[.destinationPath], response.outcome, etc.
                        switch response.outcome {
                        case .matched(let info):
                            print("══════════════════════════════════════")
                            print("📥 DEFERRED MATCHED")
                            print("path: \(info.destinationPath ?? "-")")
                            print("slug: \(info[.slug] ?? "-")")
                            print("tier: \(info[.tier] ?? "-")")
                            print("══════════════════════════════════════")
                        case .notMatched(let info):
                            print("📥 DEFERRED NOT MATCHED score=\(info[.score] ?? "-")")
                        case .failed(let error):
                            print("📥 DEFERRED FAILED: \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        matchError = error.localizedDescription
                        print("📥 DEFERRED API ERROR: \(error.localizedDescription)")
                    }
                }
                if let cached = CliqItSDK.shared.currentDeferredMatchDebugResponse {
                    matchResponse = cached
                    isMatchLoading = false
                } else if CliqItSDK.shared.hasDeferredMatchBeenReported {
                    isMatchLoading = false
                } else {
                    isMatchLoading = CliqItSDK.shared.isDeferredMatchInFlight
                }
                if let json = CliqItSDK.shared.currentMatchDebugRequestJSON {
                    matchRequestJSON = json
                }
                webFingerprint = CliqItSDK.shared.currentWebFingerprint
                combinedFingerprint = CliqItSDK.shared.combinedFingerprint
            }
        }
    }

    private var webFingerprintView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fingerprint")
                .font(.headline)

            Text("iOS WebView canvas/WebGL/audio almost always collide across phones. Uniqueness comes from locale, languages, timezone, Dynamic Type, a11y — see Combined digest.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(isCollectingFingerprint ? "Collecting…" : "Collect fingerprint") {
                collectFingerprint()
            }
            .buttonStyle(.bordered)
            .disabled(isCollectingFingerprint || isMatchLoading)

            if isCollectingFingerprint {
                ProgressView("Running canvas / WebGL / audio…")
                    .font(.caption)
            }

            if let combined = combinedFingerprint {
                Text("Combined (native + web)")
                    .font(.subheadline.bold())
                debugRow("digest", combined.shortDigest + "…")
                Text(combined.digest)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                ForEach(
                    ["deviceName", "locale", "languages", "timezone", "screen", "dynamicTypeSize", "colorScheme"]
                        .compactMap { key in combined.parts[key].map { (key, $0) } },
                    id: \.0
                ) { key, value in
                    debugRow(key, value)
                }
            }

            if let fp = webFingerprint {
                Text("WebView-only (often same on all iPhones)")
                    .font(.subheadline.bold())
                debugRow("canvasHash", fp.canvasHash ?? "—")
                debugRow("webglHash", fp.webglHash ?? "—")
                debugRow("webglVendor", fp.webglVendor ?? "—")
                debugRow("gpuRenderer", fp.gpuRenderer ?? "—")
                debugRow("audioFingerprint", fp.audioFingerprint ?? "—")
                debugRow("fontHash", fp.fontHash ?? "—")
                debugRow("jsTimezone", fp.jsTimezone ?? "—")
                debugRow("jsLanguages", fp.jsLanguages ?? "—")
                debugRow("jsScreen", fp.jsScreen ?? "—")
                debugRow(
                    "clockSkewMs",
                    fp.clockSkewMs.map { String(format: "%.2f", $0) } ?? "—"
                )
            } else if combinedFingerprint == nil {
                Text("No probe yet — run match or collect above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func collectFingerprint() {
        isCollectingFingerprint = true
        Task {
            let combined = await CliqItSDK.shared.collectCombinedFingerprint()
            await MainActor.run {
                webFingerprint = CliqItSDK.shared.currentWebFingerprint
                combinedFingerprint = combined
                isCollectingFingerprint = false
            }
        }
    }

    private var deferredMatchView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deferred Match")
                .font(.headline)

            Text("POST /api/v1/sdk/app/match")
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
        CliqItSDK.shared.runDeferredMatchDebug(
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

    private func deepLinkDebugView(_ payload: CliqItPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payload.isDeferred ? "Deferred Deep Link" : "Opened from Link")
                    .font(.headline)
                Text(payload.isDeferred ? "DEFERRED" : "DIRECT")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(payload.isDeferred ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundStyle(payload.isDeferred ? .orange : .green)
                    .clipShape(Capsule())
            }

            debugRow("URL", payload.url.absoluteString)
            debugRow("Path", payload.path)
            debugRow("Source", payload.source.rawValue)

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
