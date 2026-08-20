import CliqIt
import Foundation
import React

@objc(CliqItModule)
class CliqItModule: RCTEventEmitter {
  private var hasListeners = false

  override static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! {
    ["CliqItDeepLink", "CliqItDeferredMatch"]
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  @objc
  func configure(_ apiKey: String) {
    CliqItSDK.shared.configure(apiKey: apiKey)

    CliqItSDK.shared.onDeepLink { [weak self] payload in
      guard let self, self.hasListeners else { return }
      self.sendEvent(
        withName: "CliqItDeepLink",
        body: [
          "url": payload.url.absoluteString,
          "path": payload.path,
          "pathComponents": payload.pathComponents,
          "query": payload.queryParameters,
          "source": payload.source.rawValue,
          "isDeferred": payload.isDeferred,
        ]
      )
    }

    CliqItSDK.shared.onDeferredMatch { [weak self] outcome in
      guard let self, self.hasListeners else { return }
      switch outcome {
      case .matched(let info):
        self.sendEvent(
          withName: "CliqItDeferredMatch",
          body: [
            "status": "matched",
            "destinationPath": info.destinationPath as Any,
            "slug": info.slug as Any,
            "tier": info.tier as Any,
            "score": info.score as Any,
            "confidence": info.confidence as Any,
          ]
        )
      case .notMatched(let info):
        self.sendEvent(
          withName: "CliqItDeferredMatch",
          body: [
            "status": "notMatched",
            "tier": info.tier as Any,
            "score": info.score as Any,
          ]
        )
      case .failed(let error):
        self.sendEvent(
          withName: "CliqItDeferredMatch",
          body: [
            "status": "failed",
            "error": error.localizedDescription,
          ]
        )
      @unknown default:
        break
      }
    }
  }

  @objc
  func handleUrl(_ urlString: String) {
    guard let url = URL(string: urlString) else { return }
    _ = CliqItSDK.shared.handle(url: url)
  }

  @objc
  func getConstants() -> [AnyHashable: Any]! {
    [:]
  }
}
