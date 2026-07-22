import Foundation

#if canImport(UIKit)
import UIKit
import WebKit
#endif

/// Browser fingerprints from a hidden WKWebView (canvas / WebGL / audio / fonts).
///
/// On iOS, canvas / WebGL / audio are often identical across devices (WebKit privacy).
/// Use `MRTCombinedFingerprint` (native + web) for something that actually varies per user.
public struct MRTWebFingerprint: Sendable, Equatable {
    public let canvasHash: String?
    public let webglHash: String?
    public let webglVendor: String?
    public let webglRenderer: String?
    public let audioHash: String?
    public let clockSkewMs: Double?
    public let fontHash: String?
    public let jsTimezone: String?
    public let jsLanguages: String?
    public let jsScreen: String?

    public var gpuRenderer: String? { webglRenderer }
    public var audioFingerprint: String? { audioHash }

    public var isEmpty: Bool {
        canvasHash == nil
            && webglHash == nil
            && audioHash == nil
            && webglRenderer == nil
            && fontHash == nil
    }

    public var debugDescription: String {
        [
            "canvasHash=\(canvasHash ?? "nil")",
            "webglHash=\(webglHash ?? "nil")",
            "webglVendor=\(webglVendor ?? "nil")",
            "webglRenderer=\(webglRenderer ?? "nil")",
            "audioHash=\(audioHash ?? "nil")",
            "clockSkewMs=\(clockSkewMs.map { String($0) } ?? "nil")",
            "fontHash=\(fontHash ?? "nil")",
            "jsTimezone=\(jsTimezone ?? "nil")",
            "jsLanguages=\(jsLanguages ?? "nil")",
            "jsScreen=\(jsScreen ?? "nil")"
        ].joined(separator: ", ")
    }
}

enum MRTWebFingerprintCollector {
    private static let defaultTimeout: TimeInterval = 4.0
    private static let lock = NSLock()
    private static var _lastResult: MRTWebFingerprint?

    /// Last successful (or empty) collect from this process.
    static var lastResult: MRTWebFingerprint? {
        lock.lock()
        defer { lock.unlock() }
        return _lastResult
    }

    private static func store(_ value: MRTWebFingerprint?) {
        lock.lock()
        _lastResult = value
        lock.unlock()
    }

    /// Off-screen WKWebView — no remote page required.
    static func collect(
        domain: String? = nil,
        timeout: TimeInterval = defaultTimeout,
        debugLogging: Bool = false
    ) async -> MRTWebFingerprint? {
        _ = domain // domain unused — local HTML probe
        #if canImport(UIKit)
        if debugLogging {
            print("══════════════════════════════════════")
            print("🧪 [MRTDeepLinkSDK] WEB FINGERPRINT start (inline WKWebView)")
            print("══════════════════════════════════════")
        }

        let result: MRTWebFingerprint? = await withCheckedContinuation { continuation in
            let gate = ResumeGate(continuation: continuation)

            Task { @MainActor in
                let value = await Session.shared.run(debugLogging: debugLogging)
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

        store(result)

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

    @MainActor
    private final class Session: NSObject, WKNavigationDelegate {
        static let shared = Session()

        private var webView: WKWebView?
        private var hostView: UIView?
        private var continuation: CheckedContinuation<MRTWebFingerprint?, Never>?
        private var debugLogging = false
        private var finished = false

        func run(debugLogging: Bool) async -> MRTWebFingerprint? {
            tearDown(resumeValue: nil, force: true)

            self.debugLogging = debugLogging
            return await withCheckedContinuation { continuation in
                self.continuation = continuation
                self.finished = false
                start()
            }
        }

        private func start() {
            let config = WKWebViewConfiguration()
            config.suppressesIncrementalRendering = true
            if #available(iOS 14.0, *) {
                config.defaultWebpagePreferences.allowsContentJavaScript = true
            }

            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 8, height: 8), configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = self
            webView.alpha = 0.01

            if let window = keyWindow() {
                let host = UIView(frame: CGRect(x: 0, y: 0, width: 8, height: 8))
                host.isUserInteractionEnabled = false
                host.alpha = 0.01
                host.addSubview(webView)
                window.addSubview(host)
                self.hostView = host
                if debugLogging {
                    print("🧪 [MRTDeepLinkSDK] WKWebView attached (inline HTML)")
                }
            } else if debugLogging {
                print("🧪 [MRTDeepLinkSDK] no key window — WebGL may fail")
            }

            self.webView = webView
            webView.loadHTMLString(Self.htmlPage, baseURL: URL(string: "https://local.mrtdeeplink/"))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] WKWebView didFinish — evaluating JS")
            }

            if #available(iOS 15.0, *) {
                webView.callAsyncJavaScript(
                    "return await window.__mrtCollectFingerprint();",
                    arguments: [:],
                    in: nil,
                    in: .page
                ) { [weak self] result in
                    Task { @MainActor in
                        switch result {
                        case .success(let value):
                            if self?.debugLogging == true {
                                print("🧪 [MRTDeepLinkSDK] JS success raw: \(String(describing: value))")
                            }
                            self?.tearDown(resumeValue: Self.parse(value), force: false)
                        case .failure(let error):
                            if self?.debugLogging == true {
                                print("🧪 [MRTDeepLinkSDK] JS async failed: \(error.localizedDescription) — fallback sync")
                            }
                            self?.evaluateSyncFallback(on: webView)
                        }
                    }
                }
            } else {
                evaluateSyncFallback(on: webView)
            }
        }

        private func evaluateSyncFallback(on webView: WKWebView) {
            webView.evaluateJavaScript("window.__mrtCollectFingerprintSync()") { [weak self] result, error in
                Task { @MainActor in
                    if let error, self?.debugLogging == true {
                        print("🧪 [MRTDeepLinkSDK] JS sync failed: \(error.localizedDescription)")
                    }
                    if self?.debugLogging == true {
                        print("🧪 [MRTDeepLinkSDK] JS sync raw: \(String(describing: result))")
                    }
                    self?.tearDown(resumeValue: Self.parse(result), force: false)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] WKWebView didFail: \(error.localizedDescription)")
            }
            tearDown(resumeValue: nil, force: false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            if debugLogging {
                print("🧪 [MRTDeepLinkSDK] WKWebView provisional fail: \(error.localizedDescription)")
            }
            tearDown(resumeValue: nil, force: false)
        }

        private func tearDown(resumeValue: MRTWebFingerprint?, force: Bool) {
            if finished && !force { return }
            finished = true

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

        private static func parse(_ result: Any?) -> MRTWebFingerprint? {
            let dict: [String: Any]?
            if let d = result as? [String: Any] {
                dict = d
            } else if let d = result as? [AnyHashable: Any] {
                dict = Dictionary(uniqueKeysWithValues: d.compactMap { key, value in
                    (key as? String).map { ($0, value) }
                })
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

            let fingerprint = MRTWebFingerprint(
                canvasHash: string("canvasHash"),
                webglHash: string("webglHash"),
                webglVendor: string("webglVendor"),
                webglRenderer: string("webglRenderer"),
                audioHash: string("audioHash"),
                clockSkewMs: {
                    if let value = dict["clockSkewMs"] as? Double { return value }
                    if let value = dict["clockSkewMs"] as? Int { return Double(value) }
                    if let value = dict["clockSkewMs"] as? NSNumber { return value.doubleValue }
                    return nil
                }(),
                fontHash: string("fontHash"),
                jsTimezone: string("jsTimezone"),
                jsLanguages: string("jsLanguages"),
                jsScreen: string("jsScreen")
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

        private static let htmlPage = """
        <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head><body>
        <canvas id="c" width="280" height="80"></canvas>
        <script>
        function __mrtHash(str) {
          var h = 2166136261 >>> 0;
          for (var i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 16777619) >>> 0;
          }
          return (h >>> 0).toString(16);
        }
        function __mrtCanvas() {
          try {
            var c = document.getElementById('c') || document.createElement('canvas');
            c.width = 280; c.height = 80;
            var ctx = c.getContext('2d');
            if (!ctx) return null;
            ctx.textBaseline = 'alphabetic';
            ctx.fillStyle = '#f60';
            ctx.fillRect(10, 1, 140, 24);
            var grad = ctx.createLinearGradient(0, 0, 200, 60);
            grad.addColorStop(0, '#069');
            grad.addColorStop(1, 'rgba(102,204,0,0.7)');
            ctx.fillStyle = grad;
            ctx.font = '16px Arial';
            ctx.fillText('MRTDeepLink,fp 🌐', 2, 20);
            ctx.font = '14px "Courier New"';
            ctx.fillText('mmmmmmmmmlli', 2, 42);
            ctx.font = '12px Georgia';
            ctx.fillText('Cwm fjord bank 😀', 2, 60);
            ctx.beginPath();
            ctx.arc(220, 40, 18, 0, Math.PI * 2);
            ctx.strokeStyle = '#c33';
            ctx.stroke();
            return __mrtHash(c.toDataURL());
          } catch (e) { return null; }
        }
        function __mrtFonts() {
          try {
            var base = ['monospace', 'sans-serif', 'serif'];
            var test = ['Arial','Helvetica','Times New Roman','Courier New','Georgia','Verdana','Menlo','Avenir','PingFang SC','Hiragino Sans'];
            var body = document.body;
            var span = document.createElement('span');
            span.style.fontSize = '72px';
            span.style.position = 'absolute';
            span.style.left = '-9999px';
            span.textContent = 'mmmmmmmmmlli';
            body.appendChild(span);
            var widths = {};
            for (var b = 0; b < base.length; b++) {
              span.style.fontFamily = base[b];
              widths[base[b]] = span.offsetWidth + 'x' + span.offsetHeight;
            }
            var detected = [];
            for (var i = 0; i < test.length; i++) {
              var name = test[i];
              var hit = false;
              for (var j = 0; j < base.length; j++) {
                span.style.fontFamily = '"' + name + '",' + base[j];
                var key = base[j];
                if ((span.offsetWidth + 'x' + span.offsetHeight) !== widths[key]) { hit = true; break; }
              }
              if (hit) detected.push(name);
            }
            body.removeChild(span);
            return __mrtHash(detected.join(','));
          } catch (e) { return null; }
        }
        function __mrtWebGL() {
          try {
            var c = document.createElement('canvas');
            c.width = 16; c.height = 16;
            var gl = c.getContext('webgl') || c.getContext('experimental-webgl');
            if (!gl) return { hash: null, vendor: null, renderer: null };
            var dbg = gl.getExtension('WEBGL_debug_renderer_info');
            var vendor = dbg ? String(gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL)) : String(gl.getParameter(gl.VENDOR));
            var renderer = dbg ? String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL)) : String(gl.getParameter(gl.RENDERER));
            var params = [
              String(gl.getParameter(gl.VERSION) || ''),
              String(gl.getParameter(gl.SHADING_LANGUAGE_VERSION) || ''),
              vendor || '',
              renderer || '',
              String(gl.getParameter(gl.MAX_TEXTURE_SIZE) || ''),
              String(gl.getParameter(gl.MAX_RENDERBUFFER_SIZE) || ''),
              (gl.getSupportedExtensions() || []).join(',')
            ].join('|');
            return { hash: __mrtHash(params), vendor: vendor || null, renderer: renderer || null };
          } catch (e) {
            return { hash: null, vendor: null, renderer: null };
          }
        }
        function __mrtAudio() {
          return new Promise(function(resolve) {
            var settled = false;
            function done(v) { if (settled) return; settled = true; resolve(v); }
            try {
              var AC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
              if (!AC) { done(null); return; }
              var ctx = new AC(1, 44100, 44100);
              var osc = ctx.createOscillator();
              var comp = ctx.createDynamicsCompressor();
              osc.type = 'triangle';
              osc.frequency.value = 10000;
              comp.threshold.value = -50;
              comp.knee.value = 40;
              comp.ratio.value = 12;
              comp.attack.value = 0;
              comp.release.value = 0.25;
              osc.connect(comp);
              comp.connect(ctx.destination);
              osc.start(0);
              ctx.oncomplete = function(ev) {
                try {
                  var data = ev.renderedBuffer.getChannelData(0);
                  var sum = 0;
                  for (var i = 4500; i < 5000; i++) sum += Math.abs(data[i]);
                  done(__mrtHash(String(sum)));
                } catch (e) { done(null); }
              };
              ctx.startRendering();
              setTimeout(function() { done(null); }, 700);
            } catch (e) { done(null); }
          });
        }
        window.__mrtCollectFingerprintSync = function() {
          var gl = __mrtWebGL();
          var skew = null;
          try {
            if (window.performance && typeof performance.now === 'function' && performance.timeOrigin) {
              skew = Date.now() - (performance.timeOrigin + performance.now());
            }
          } catch (e) {}
          var tz = null, langs = null, screen = null;
          try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || null; } catch (e) {}
          try { langs = (navigator.languages || [navigator.language]).join(','); } catch (e) {}
          try { screen = (window.screen.width||0) + 'x' + (window.screen.height||0) + '@' + (window.devicePixelRatio||1); } catch (e) {}
          return {
            canvasHash: __mrtCanvas(),
            webglHash: gl.hash,
            webglVendor: gl.vendor,
            webglRenderer: gl.renderer,
            audioHash: null,
            clockSkewMs: skew,
            fontHash: __mrtFonts(),
            jsTimezone: tz,
            jsLanguages: langs,
            jsScreen: screen
          };
        };
        window.__mrtCollectFingerprint = async function() {
          var sync = window.__mrtCollectFingerprintSync();
          sync.audioHash = await __mrtAudio();
          return sync;
        };
        </script></body></html>
        """
    }
    #endif
}
