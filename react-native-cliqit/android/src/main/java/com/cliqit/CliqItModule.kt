package com.cliqit

import com.cliqit.sdk.CliqItSDK
import com.cliqit.sdk.LinkField
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class CliqItModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private var hasListeners = false
  private var pendingLink: WritableMap? = null
  private var handlersBound = false

  override fun getName(): String = "CliqItModule"

  override fun getConstants(): MutableMap<String, Any> = hashMapOf(
    "LinkField" to hashMapOf(
      "destination" to LinkField.destination,
      "iosDestination" to LinkField.iosDestination,
      "androidDestination" to LinkField.androidDestination,
      "ogTitle" to LinkField.ogTitle,
      "ogDescription" to LinkField.ogDescription,
      "ogImage" to LinkField.ogImage,
      "ogUrl" to LinkField.ogUrl,
      "slug" to LinkField.slug,
      "webFallback" to LinkField.webFallback,
      "showInterstitial" to LinkField.showInterstitial,
      "isDeepLink" to LinkField.isDeepLink,
      "appleTeamId" to LinkField.appleTeamId,
      "iosBundleId" to LinkField.iosBundleId,
      "androidPackageName" to LinkField.androidPackageName,
      "resolvedPath" to LinkField.resolvedPath,
    ),
  )

  @ReactMethod
  fun addListener(eventName: String) {
    hasListeners = true
    flushPending()
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    if (count > 0) hasListeners = false
  }

  @ReactMethod
  fun configure(apiKey: String) {
    CliqItSDK.init(reactContext)
    bindHandlersIfNeeded()
    CliqItSDK.configure(apiKey)
  }

  @ReactMethod
  fun handleUrl(url: String) {
    CliqItSDK.init(reactContext)
    CliqItSDK.handle(url)
  }

  private fun bindHandlersIfNeeded() {
    if (handlersBound) return
    handlersBound = true

    CliqItSDK.onLinkReceived { payload ->
      val query = Arguments.createMap()
      payload.query.forEach { (k, v) -> query.putString(k, v) }
      val components = Arguments.createArray()
      payload.pathComponents.forEach { components.pushString(it) }
      val map = Arguments.createMap().apply {
        putString("url", payload.url)
        putString("path", payload.path)
        putArray("pathComponents", components)
        putMap("query", query)
        putString("source", payload.source)
        putBoolean("isDeferred", payload.isDeferred)
        putString("status", payload.status)
        payload.matched?.let { putBoolean("matched", it) }
        putOpt(this, "tier", payload.tier)
        putOpt(this, "confidence", payload.confidence)
        payload.score?.let { putDouble("score", it) }
        putOpt(this, "slug", payload.slug)
        putOpt(this, "destinationPath", payload.destinationPath)
        putOpt(this, "error", payload.errorMessage)
        putBoolean("shouldNavigate", payload.shouldNavigate)
      }
      if (hasListeners) sendEvent("CliqItLinkReceived", map) else pendingLink = map
    }
  }

  private fun flushPending() {
    pendingLink?.let {
      pendingLink = null
      sendEvent("CliqItLinkReceived", it)
    }
  }

  private fun sendEvent(event: String, params: WritableMap) {
    if (!reactContext.hasActiveReactInstance()) return
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit(event, params)
  }

  private fun putOpt(map: WritableMap, key: String, value: String?) {
    if (value != null) map.putString(key, value) else map.putNull(key)
  }
}
