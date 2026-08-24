package com.cliqit

import com.cliqit.sdk.CliqItSDK
import com.cliqit.sdk.LinkField
import com.cliqit.sdk.LinkLookupResult
import com.cliqit.sdk.VerifyOutcome
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule

class CliqItModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private var hasListeners = false
  private var pendingDeepLink: WritableMap? = null
  private var pendingLinkLookup: WritableMap? = null
  private var pendingVerify: WritableMap? = null
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
    CliqItSDK.notifyAlreadyReportedIfNeeded()
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
      emitOrBuffer("CliqItLinkReceived", map) { pendingDeepLink = it }
    }

    CliqItSDK.onDirectLinkLookup { result ->
      val map = Arguments.createMap()
      when (result) {
        is LinkLookupResult.Resolved -> {
          val d = result.details
          map.putString("status", "resolved")
          putOpt(map, LinkField.destination, d.destination)
          putOpt(map, LinkField.iosDestination, d.iosDestination)
          putOpt(map, LinkField.androidDestination, d.androidDestination)
          putOpt(map, LinkField.ogTitle, d.ogTitle)
          putOpt(map, LinkField.ogDescription, d.ogDescription)
          putOpt(map, LinkField.ogImage, d.ogImage)
          putOpt(map, LinkField.ogUrl, d.ogUrl)
          putOpt(map, LinkField.slug, d.slug)
          putOpt(map, LinkField.webFallback, d.webFallback)
          putOpt(map, LinkField.showInterstitial, d.field(LinkField.showInterstitial))
          putOpt(map, LinkField.isDeepLink, d.field(LinkField.isDeepLink))
          putOpt(map, LinkField.appleTeamId, d.appleTeamId)
          putOpt(map, LinkField.iosBundleId, d.iosBundleId)
          putOpt(map, LinkField.androidPackageName, d.androidPackageName)
          putOpt(map, LinkField.resolvedPath, d.resolvedPath)
        }
        is LinkLookupResult.Failed -> {
          map.putString("status", "failed")
          map.putString("error", result.error)
        }
      }
      emitOrBuffer("CliqItLinkLookup", map) { pendingLinkLookup = it }
    }

    CliqItSDK.onVerify { outcome ->
      val map = Arguments.createMap()
      when (outcome) {
        is VerifyOutcome.Passed -> {
          map.putString("status", "ok")
          map.putBoolean("ok", true)
          putOpt(map, "appId", outcome.result.appId)
          putOpt(map, "appName", outcome.result.appName)
          map.putString("message", outcome.result.mismatchMessage)
          map.putMap("checks", checksMap(outcome.result.checks))
          map.putString("raw", outcome.result.rawJSON)
        }
        is VerifyOutcome.Mismatched -> {
          map.putString("status", "mismatch")
          map.putBoolean("ok", false)
          putOpt(map, "appId", outcome.result.appId)
          putOpt(map, "appName", outcome.result.appName)
          map.putString("message", outcome.result.mismatchMessage)
          map.putMap("checks", checksMap(outcome.result.checks))
          map.putString("raw", outcome.result.rawJSON)
        }
        is VerifyOutcome.Error -> {
          map.putString("status", "failed")
          map.putBoolean("ok", false)
          map.putString("error", outcome.message)
        }
      }
      emitOrBuffer("CliqItVerify", map) { pendingVerify = it }
    }
  }

  private fun checksMap(checks: Map<String, com.cliqit.sdk.VerifyCheck>): WritableMap {
    val out = Arguments.createMap()
    checks.forEach { (key, check) ->
      val item = Arguments.createMap()
      putOpt(item, "actual", check.actual)
      putOpt(item, "expected", check.expected)
      item.putBoolean("match", check.match)
      out.putMap(key, item)
    }
    return out
  }

  private fun emitOrBuffer(
    event: String,
    body: WritableMap,
    buffer: (WritableMap) -> Unit,
  ) {
    if (hasListeners) {
      sendEvent(event, body)
    } else {
      buffer(body)
    }
  }

  private fun flushPending() {
    pendingDeepLink?.let {
      pendingDeepLink = null
      sendEvent("CliqItLinkReceived", it)
    }
    pendingLinkLookup?.let {
      pendingLinkLookup = null
      sendEvent("CliqItLinkLookup", it)
    }
    pendingVerify?.let {
      pendingVerify = null
      sendEvent("CliqItVerify", it)
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
