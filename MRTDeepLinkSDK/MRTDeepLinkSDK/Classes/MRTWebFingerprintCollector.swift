import Foundation

#if canImport(UIKit)
import UIKit
import WebKit
#endif

/// Fingerprint payload from `https://<domain>/fp-probe` (same JS as web click interstitial).
public struct MRTWebFingerprint: Sendable, Equatable {
    public let source: String?
    public let timezone: String?
    public let screenBucket: String?
    public let connectionType: String?
    public let localeJs: String?
    public let devicePixelRatioBucket: String?
    public let languagesOrdered: String?
    public let colorScheme: String?
    public let hourCycle: String?
    public let currency: String?
    public let regionCode: String?
    public let dynamicTypeSize: String?
    public let boldText: Bool?
    public let reduceMotion: Bool?
    public let increaseContrast: Bool?
    public let hardwareConcurrency: Int?
    public let clockSkewMs: Double?
    public let canvasHash: String?
    public let gpuRenderer: String?
    public let audioFingerprint: String?
    public let batteryLevel: Double?
    public let batteryCharging: Bool?

    public var isEmpty: Bool {
        canvasHash == nil
            && gpuRenderer == nil
            && audioFingerprint == nil
            && clockSkewMs == nil
            && devicePixelRatioBucket == nil
            && hourCycle == nil
            && currency == nil
            && regionCode == nil
    }

    public var debugDescription: String {
        [
            "source=\(source ?? "nil")",
            "canvasHash=\(canvasHash ?? "nil")",
            "gpuRenderer=\(gpuRenderer ?? "nil")",
            "audioFingerprint=\(audioFingerprint ?? "nil")",
            "clockSkewMs=\(clockSkewMs.map { String($0) } ?? "nil")",
            "devicePixelRatioBucket=\(devicePixelRatioBucket ?? "nil")"
        ].joined(separator: ", ")
    }
}

enum MRTWebFingerprintCollector {
    private static let defaultTimeout: TimeInterval = 4.0

    /// Loads `/fp-probe` in an off-screen WKWebView and returns the bridge payload.
    static func collect(
        domain: String?,
        timeout: TimeInterval = defaultTimeout,
        debugLogging: Bool = false
    ) async -> MRTWebFingerprint? {
        #if canImport(UIKit)
        guard let domain, !domain.isEmpty else {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT skipped — no probe domain")
            }
            return nil
        }

        let host = Self.normalizedHost(domain)
        guard let probeURL = URL(string: "https://\(host)/fp-probe") else {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT invalid probe URL for \(host)")
            }
            return nil
        }

        if debugLogging {
            print("══════════════════════════════════════")
            print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT start")
            print("probe: \(probeURL.absoluteString)")
            print("══════════════════════════════════════")
        }

        let result: MRTWebFingerprint? = await withCheckedContinuation { continuation in
            let gate = ResumeGate(continuation: continuation)

            Task { @MainActor in
                let value = await Session.shared.run(probeURL: probeURL, debugLogging: debugLogging)
                gate.resume(value)
            }

            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if debugLogging {
                    print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT timeout (\(timeout)s)")
                }
                gate.resume(nil)
            }
        }

        if debugLogging {
            if let result {
                print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT ok: \(result.debugDescription)")
            } else {
                print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT failed / empty")
            }
            print("══════════════════════════════════════")
        }
        return result
        #else
        return nil
        #endif
    }

    private static func normalizedHost(_ value: String) -> String {
        if value.hasPrefix("http://") || value.hasPrefix("https://"),
           let host = URL(string: value)?.host {
            return host
        }
        return value
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    #if canImport(UIKit)
    private final class ResumeGate: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<MRTWebFingerprint?, Never>?

        init(continuation: CheckedContinuation<MRTWebFingerprint?, Never>) {
            self.continuation = continuation
        }

        func resume(_ value: MRTWebFingerprint?) {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(returning: value)
        }
    }

    /// Strongly retained while a collect is in flight.
    @MainActor
    private final class Session: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let shared = Session()

        private var webView: WKWebView?
        private var hostView: UIView?
        private var continuation: CheckedContinuation<MRTWebFingerprint?, Never>?
        private var debugLogging = false
        private var finished = false

        func run(probeURL: URL, debugLogging: Bool) async -> MRTWebFingerprint? {
            tearDown(resumeValue: nil, force: true)

            self.debugLogging = debugLogging
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.finished = false
                start(probeURL: probeURL)
            }
        }

        private func start(probeURL: URL) {
            let controller = WKUserContentController()
            controller.add(self, name: "fp")

            let config = WKWebViewConfiguration()
            config.userContentController = controller
            config.suppressesIncrementalRendering = true
            if #available(iOS 14.0, *) {
                config.defaultWebpagePreferences.allowsContentJavaScript = true
            }

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = self
            webView.alpha = 0.01

            if let window = keyWindow() {
                let host = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
                host.isUserInteractionEnabled = false
                host.alpha = 0.01
                host.addSubview(webView)
                window.addSubview(host)
                self.hostView = host
                if debugLogging {
                    print("🧪 [MRTDeepLinkSDK] WKWebView attached — loading fp-probe")
                }
            } else if debugLogging {
                print("🧪 [MRTDeepLinkSDK] no key window — fp-probe may fail")
            }

            self.webView = webView
            webView.load(URLRequest(url: probeURL))
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "fp" else { return }

            let fingerprint = Self.parse(message.body)
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] fp bridge message received")
            }
            tearDown(resumeValue: fingerprint, force: false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] fp-probe didFail: \(error.localizedDescription)")
            }
            tearDown(resumeValue: nil, force: false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] fp-probe provisional fail: \(error.localizedDescription)")
            }
            tearDown(resumeValue: nil, force: false)
        }

        private func tearDown(resumeValue: MRTWebFingerprint?, force: Bool) {
            if finished && !force { return }
            finished = true

            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "fp")
            webView?.navigationDelegate = nil
            webView?.stopLoading()
            webView?.removeFromSuperview()
            hostView?.removeFromSuperview()
            webView = nil
            hostView = nil

            let cont = continuation
            continuation = nil
            cont?.resume(returning: resumeValue)
        }

        private static func parse(_ body: Any) -> MRTWebFingerprint? {
            let dict: [String: Any]?
            if let jsonStr = body as? String,
               let data = jsonStr.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict = object
            } else if let object = body as? [String: Any] {
                dict = object
            } else if let data = body as? Data,
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict = object
            } else {
                return nil
            }

            guard let dict else { return nil }

            func string(_ key: String) -> String? {
                if let value = dict[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty || trimmed == "null" ? nil : trimmed
                }
                if dict[key] is NSNull { return nil }
                return nil
            }

            func bool(_ key: String) -> Bool? {
                if let value = dict[key] as? Bool { return value }
                if let value = dict[key] as? NSNumber { return value.boolValue }
                return nil
            }

            func double(_ key: String) -> Double? {
                if let value = dict[key] as? Double { return value }
                if let value = dict[key] as? Int { return Double(value) }
                if let value = dict[key] as? NSNumber { return value.doubleValue }
                return nil
            }

            func int(_ key: String) -> Int? {
                if let value = dict[key] as? Int { return value }
                if let value = dict[key] as? Double { return Int(value) }
                if let value = dict[key] as? NSNumber { return value.intValue }
                return nil
            }

            let fingerprint = MRTWebFingerprint(
                source: string("source"),
                timezone: string("timezone"),
                screenBucket: string("screen_bucket"),
                connectionType: string("connection_type"),
                localeJs: string("locale_js"),
                devicePixelRatioBucket: string("device_pixel_ratio_bucket"),
                languagesOrdered: string("languages_ordered"),
                colorScheme: string("color_scheme"),
                hourCycle: string("hour_cycle"),
                currency: string("currency"),
                regionCode: string("region_code"),
                dynamicTypeSize: string("dynamic_type_size"),
                boldText: bool("bold_text"),
                reduceMotion: bool("reduce_motion"),
                increaseContrast: bool("increase_contrast"),
                hardwareConcurrency: int("hardware_concurrency"),
                clockSkewMs: double("clock_skew_ms"),
                canvasHash: string("canvas_hash"),
                gpuRenderer: string("gpu_renderer"),
                audioFingerprint: string("audio_fingerprint"),
                batteryLevel: double("battery_level"),
                batteryCharging: bool("battery_charging")
            )
            return fingerprint.isEmpty ? nil : fingerprint
        }

        private func keyWindow() -> UIWindow? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
                ?? UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .first
        }
    }
    #endif
}
