package com.cliqit

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

/**
 * Android stub — native CliqIt SDK is iOS-only for now.
 */
class CliqItModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String = "CliqItModule"

  @ReactMethod
  fun configure(apiKey: String) {
    // no-op
  }

  @ReactMethod
  fun handleUrl(url: String) {
    // no-op
  }
}
