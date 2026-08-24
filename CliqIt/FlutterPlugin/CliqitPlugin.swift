import Flutter
import UIKit
#if canImport(CliqIt)
import CliqIt
#endif

/// Flutter plugin — compile with `CliqIt/Classes/*.swift` in the same iOS target (no XCFramework).
/// If those files live in `ios/Classes/`, drop `import CliqIt` (already handled by canImport).
public final class CliqitPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, FlutterSceneLifeCycleDelegate {
  private var linkEventSink: FlutterEventSink?
  private var channel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = CliqitPlugin()

    let method = FlutterMethodChannel(
      name: "cliqit",
      binaryMessenger: registrar.messenger()
    )
    instance.channel = method
    registrar.addMethodCallDelegate(instance, channel: method)

    // One stream for all link / deferred / error outcomes
    let events = FlutterEventChannel(
      name: "cliqit/onLinkReceived",
      binaryMessenger: registrar.messenger()
    )
    instance.eventChannel = events
    events.setStreamHandler(instance)

    registrar.addApplicationDelegate(instance) // older hosts
    registrar.addSceneDelegate(instance)       // UIScene (required)

    // Wire SDK → Flutter once
    CliqItSDK.shared.onLinkReceived { [weak instance] payload in
      instance?.emit(payload)
    }
  }

  // MARK: - MethodChannel

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "configure":
      guard
        let args = call.arguments as? [String: Any],
        let apiKey = args["apiKey"] as? String,
        !apiKey.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "apiKey required", details: nil))
        return
      }
      CliqItSDK.shared.configure(apiKey: apiKey)
      result(["ok": true])

    case "handleUrl":
      guard
        let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(FlutterError(code: "bad_args", message: "url required", details: nil))
        return
      }
      let ok = CliqItSDK.shared.handle(url: url)
      result(["ok": ok, "url": urlString])

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - EventChannel (onLinkReceived)

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    linkEventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    linkEventSink = nil
    return nil
  }

  private func emit(_ payload: CliqItPayload) {
    // Restart must not look like a deep link (placeholder API url + alreadyReported).
    guard payload.status != .alreadyReported else { return }
    guard let sink = linkEventSink else { return }
    DispatchQueue.main.async {
      sink(Self.map(payload))
    }
  }

  private static func map(_ payload: CliqItPayload) -> [String: Any] {
    var body: [String: Any] = [
      "url": payload.url.absoluteString,
      "path": payload.path,
      "pathComponents": payload.pathComponents,
      "query": payload.queryParameters,
      "source": payload.source.rawValue,
      "isDeferred": payload.isDeferred,
      "status": payload.status.rawValue,
      "shouldNavigate": payload.shouldNavigate,
    ]
    if let matched = payload.matched { body["matched"] = matched }
    if let tier = payload.tier { body["tier"] = tier }
    if let confidence = payload.confidence { body["confidence"] = confidence }
    if let score = payload.score { body["score"] = score }
    if let slug = payload.slug { body["slug"] = slug }
    if let destinationPath = payload.destinationPath { body["destinationPath"] = destinationPath }
    if let errorMessage = payload.errorMessage { body["error"] = errorMessage }
    return body
  }

  // MARK: - UIScene (deep links)

  public func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let options = connectionOptions {
      CliqItSceneSupport.handle(connectionOptions: options)
    }
    return false
  }

  public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    CliqItSceneSupport.handle(urlContexts: URLContexts)
    return true
  }

  public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
    CliqItSceneSupport.handle(userActivity: userActivity)
  }

  // MARK: - Legacy AppDelegate URL hooks (optional)

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    CliqItSDK.shared.handle(url: url)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    CliqItSDK.shared.handle(userActivity: userActivity)
  }
}
