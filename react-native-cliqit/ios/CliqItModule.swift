import CliqIt
import Foundation
import React

@objc(CliqItModule)
class CliqItModule: RCTEventEmitter {
  private var hasListeners = false
  // ponytail: RN listeners attach after configure; buffer one shot so events aren't dropped
  private var pendingDeepLink: [String: Any]?
  private var pendingLinkLookup: [String: Any]?
  private var pendingVerify: [String: Any]?

  override static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! {
    ["CliqItLinkReceived", "CliqItLinkLookup", "CliqItVerify"]
  }

  override func startObserving() {
    hasListeners = true
    flushPending()
  }

  override func stopObserving() {
    hasListeners = false
  }

  @objc
  func configure(_ apiKey: String) {
    CliqItSDK.shared.onVerify { [weak self] result in
      self?.emitVerify(result)
    }

    CliqItSDK.shared.configure(apiKey: apiKey)

    CliqItSDK.shared.onLinkReceived { [weak self] payload in
      self?.emitLinkReceived(payload)
    }

    CliqItSDK.shared.onDirectLinkLookup { [weak self] result in
      self?.emitLinkLookup(result)
    }

    CliqItSDK.shared.notifyAlreadyReportedIfNeeded()
  }

  @objc
  func handleUrl(_ urlString: String) {
    guard let url = URL(string: urlString) else { return }
    _ = CliqItSDK.shared.handle(url: url)
  }

  override func constantsToExport() -> [AnyHashable: Any]! {
    [
      "LinkField": [
        "destination": CliqItLinkField.destination.rawValue,
        "iosDestination": CliqItLinkField.iosDestination.rawValue,
        "androidDestination": CliqItLinkField.androidDestination.rawValue,
        "ogTitle": CliqItLinkField.ogTitle.rawValue,
        "ogDescription": CliqItLinkField.ogDescription.rawValue,
        "ogImage": CliqItLinkField.ogImage.rawValue,
        "ogUrl": CliqItLinkField.ogUrl.rawValue,
        "slug": CliqItLinkField.slug.rawValue,
        "webFallback": CliqItLinkField.webFallback.rawValue,
        "showInterstitial": CliqItLinkField.showInterstitial.rawValue,
        "isDeepLink": CliqItLinkField.isDeepLink.rawValue,
        "appleTeamId": CliqItLinkField.appleTeamId.rawValue,
        "iosBundleId": CliqItLinkField.iosBundleId.rawValue,
        "androidPackageName": CliqItLinkField.androidPackageName.rawValue,
        "resolvedPath": CliqItLinkField.resolvedPath.rawValue,
      ],
    ]
  }

  // MARK: - Emit / buffer

  private func emitLinkReceived(_ payload: CliqItPayload) {
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
    emitBody(event: "CliqItLinkReceived", body: body, pendingKey: \.pendingDeepLink)
  }

  private func emitLinkLookup(_ result: Result<CliqItLinkDetails, CliqItDeferredMatchError>) {
    let body: [String: Any]
    switch result {
    case .success(let details):
      body = [
        "status": "resolved",
        "destination": details[.destination] as Any,
        "iosDestination": details[.iosDestination] as Any,
        "androidDestination": details[.androidDestination] as Any,
        "ogTitle": details[.ogTitle] as Any,
        "ogDescription": details[.ogDescription] as Any,
        "ogImage": details[.ogImage] as Any,
        "ogUrl": details[.ogUrl] as Any,
        "slug": details[.slug] as Any,
        "webFallback": details[.webFallback] as Any,
        "showInterstitial": details[.showInterstitial] as Any,
        "isDeepLink": details[.isDeepLink] as Any,
        "appleTeamId": details[.appleTeamId] as Any,
        "iosBundleId": details[.iosBundleId] as Any,
        "androidPackageName": details[.androidPackageName] as Any,
        "resolvedPath": details[.resolvedPath] as Any,
      ]
    case .failure(let error):
      body = [
        "status": "failed",
        "error": error.localizedDescription,
      ]
    }
    emitBody(event: "CliqItLinkLookup", body: body, pendingKey: \.pendingLinkLookup)
  }

  private func emitVerify(_ outcome: CliqItVerifyOutcome) {
    var body: [String: Any] = [:]
    switch outcome {
    case .passed(let r):
      body = verifyBody(status: "ok", result: r)
    case .mismatched(let r):
      body = verifyBody(status: "mismatch", result: r)
      body["message"] = r.mismatchMessage
    case .error(let error):
      body = [
        "status": "failed",
        "ok": false,
        "error": error.localizedDescription,
      ]
    }
    if let raw = CliqItSDK.shared.currentVerifyJSON {
      body["raw"] = raw
    }
    emitBody(event: "CliqItVerify", body: body, pendingKey: \.pendingVerify)
  }

  private func verifyBody(status: String, result: CliqItVerifyResult) -> [String: Any] {
    var checks: [String: Any] = [:]
    for (key, check) in result.checks {
      checks[key] = [
        "actual": check.actual as Any,
        "expected": check.expected as Any,
        "match": check.match,
      ]
    }
    return [
      "status": status,
      "ok": result.ok,
      "appId": result.appId as Any,
      "appName": result.appName as Any,
      "checks": checks,
      "message": result.mismatchMessage,
    ]
  }

  private func emitBody(
    event: String,
    body: [String: Any],
    pendingKey: ReferenceWritableKeyPath<CliqItModule, [String: Any]?>
  ) {
    if hasListeners {
      sendEvent(withName: event, body: body)
    } else {
      self[keyPath: pendingKey] = body
    }
  }

  private func flushPending() {
    if let deep = pendingDeepLink {
      pendingDeepLink = nil
      sendEvent(withName: "CliqItLinkReceived", body: deep)
    }
    if let lookup = pendingLinkLookup {
      pendingLinkLookup = nil
      sendEvent(withName: "CliqItLinkLookup", body: lookup)
    }
    if let verify = pendingVerify {
      pendingVerify = nil
      sendEvent(withName: "CliqItVerify", body: verify)
    }
  }
}
