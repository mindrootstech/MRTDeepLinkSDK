package com.cliqit.sdk

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android port of iOS CliqItSDK — configure, deferred match, direct link lookup, handle(url).
 */
object CliqItSDK {
  private const val TAG = "CliqIt"

  @Volatile private var appContext: Context? = null
  @Volatile private var apiKey: String? = null

  private var deepLinkHandler: ((CliqItPayload) -> Unit)? = null
  private var deferredHandler: ((DeferredMatchOutcome) -> Unit)? = null
  private var linkLookupHandler: ((LinkLookupResult) -> Unit)? = null
  private var verifyHandler: ((VerifyOutcome) -> Unit)? = null

  private var pendingPayload: CliqItPayload? = null
  private var lastLinkDetails: LinkDetails? = null
  private var lastDeferredOutcome: DeferredMatchOutcome? = null
  private var lastVerifyJSON: String? = null
  private var lastVerifyOutcome: VerifyOutcome? = null
  private var launchClickSessionId: String? = null
  private var receivedDirectThisSession = false
  private val matchInFlight = AtomicBoolean(false)

  private val mainHandler = Handler(Looper.getMainLooper())
  private val io = Executors.newSingleThreadExecutor()

  val isConfigured: Boolean get() = apiKey != null && appContext != null

  val hasDeferredMatchBeenReported: Boolean
    get() = prefs()?.getBoolean(CliqItDefaults.KEY_MATCH_REPORTED, false) == true

  val isDeferredMatchInFlight: Boolean get() = matchInFlight.get()

  fun init(context: Context) {
    appContext = context.applicationContext
  }

  fun configure(apiKey: String) {
    if (appContext == null) {
      throw IllegalStateException("Call CliqItSDK.init(context) before configure")
    }
    this.apiKey = apiKey
    Log.i(TAG, "✅ configured")
    verifyInBackground()
    beginDeferredMatchIfNeeded()
  }

  fun onLinkReceived(handler: (CliqItPayload) -> Unit) {
    deepLinkHandler = handler
    pendingPayload?.let {
      pendingPayload = null
      mainHandler.post { handler(it) }
    }
  }

  @Deprecated("Use onLinkReceived", ReplaceWith("onLinkReceived(handler)"))
  fun onDeepLink(handler: (CliqItPayload) -> Unit) = onLinkReceived(handler)

  @Deprecated("Use onLinkReceived — unified payload for direct + deferred")
  fun onDeferredMatch(handler: (DeferredMatchOutcome) -> Unit) {
    deferredHandler = handler
    lastDeferredOutcome?.let { outcome ->
      mainHandler.post { handler(outcome) }
    }
  }

  /** Emit alreadyReported via onLinkReceived when match already ran this install. */
  fun notifyAlreadyReportedIfNeeded() {
    if (!hasDeferredMatchBeenReported || isDeferredMatchInFlight) return
    deliver(
      CliqItPayload(
        url = CliqItDefaults.SERVER_URL,
        path = "",
        pathComponents = emptyList(),
        query = emptyMap(),
        source = "deferred",
        isDeferred = true,
        status = "alreadyReported",
        errorMessage = "Deferred match already ran on this install.",
      ),
    )
  }

  fun onDirectLinkLookup(handler: (LinkLookupResult) -> Unit) {
    linkLookupHandler = handler
    lastLinkDetails?.let { details ->
      mainHandler.post { handler(LinkLookupResult.Resolved(details)) }
    }
  }

  fun onVerify(handler: (VerifyOutcome) -> Unit) {
    verifyHandler = handler
    lastVerifyOutcome?.let { outcome ->
      mainHandler.post { handler(outcome) }
    }
  }

  fun handle(urlString: String): Boolean {
    val uri = Uri.parse(urlString) ?: return false
    return handle(uri)
  }

  fun handle(uri: Uri): Boolean {
    captureClickSessionId(uri)
    val key = apiKey
    val ctx = appContext
    if (key == null || ctx == null) {
      pendingPayload = parsePayload(uri, source = "unknown", isDeferred = false)
      return false
    }

    if (!isAllowedUrl(uri)) {
      Log.i(TAG, "Ignored unsupported URL: $uri")
      return false
    }

    val payload = parsePayload(uri, source = detectSource(uri), isDeferred = false)
    receivedDirectThisSession = true

    val slug = slugFrom(uri)
    if (slug != null) {
      fetchLinkDetails(key, uri, slug, payload)
      return true
    }

    deliver(payload)
    return true
  }

  private fun parseVerifyOutcome(body: String): VerifyOutcome {
    return try {
      val root = JSONObject(body)
      val checksObj = root.optJSONObject("checks")
      val checks = mutableMapOf<String, VerifyCheck>()
      if (checksObj != null) {
        val keys = checksObj.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          val item = checksObj.optJSONObject(key) ?: continue
          checks[key] = VerifyCheck(
            actual = CliqItHttp.optString(item, "actual"),
            expected = CliqItHttp.optString(item, "expected"),
            match = item.optBoolean("match", false),
          )
        }
      }
      val result = VerifyResult(
        ok = root.optBoolean("ok", false),
        appId = CliqItHttp.optString(root, "appId"),
        appName = CliqItHttp.optString(root, "appName"),
        checks = checks,
        rawJSON = body,
      )
      if (result.ok) VerifyOutcome.Passed(result) else VerifyOutcome.Mismatched(result)
    } catch (e: Exception) {
      VerifyOutcome.Error(e.message ?: "Invalid verify response")
    }
  }

  private fun beginDeferredMatchIfNeeded() {
    if (hasDeferredMatchBeenReported) return
    val key = apiKey ?: return
    val ctx = appContext ?: return
    performDeferredMatch(ctx, key, markReported = true)
  }

  private fun verifyInBackground() {
    val key = apiKey ?: return
    val ctx = appContext ?: return
    io.execute {
      val body = JSONObject().apply {
        put("platform", "android")
        put("packageName", CliqItDeviceInfo.packageName(ctx))
        putOpt("androidSha256", CliqItDeviceInfo.androidSha256(ctx))
      }
      val url = CliqItHttp.joinUrl(
        CliqItDefaults.SERVER_URL,
        *CliqItDefaults.VERIFY_PATH.split('/').filter { it.isNotEmpty() }.toTypedArray(),
      )
      CliqItHttp.postJson(url, key, body.toString()).fold(
        onSuccess = { response ->
          lastVerifyJSON = response.body
          val outcome = parseVerifyOutcome(response.body)
          lastVerifyOutcome = outcome
          when (outcome) {
            is VerifyOutcome.Passed ->
              Log.i(TAG, "✅ verify OK — ${outcome.result.appName ?: "app"} (${outcome.result.appId ?: "-"})")
            is VerifyOutcome.Mismatched -> {
              Log.e(TAG, "❌ verify MISMATCH (ok=false)")
              Log.e(TAG, "   appName: ${outcome.result.appName ?: "-"}")
              Log.e(TAG, "   appId:   ${outcome.result.appId ?: "-"}")
              outcome.result.failedChecks.forEach { (field, check) ->
                Log.e(TAG, "   • $field: actual=${check.actual ?: "-"} expected=${check.expected ?: "-"}")
              }
              Log.e(TAG, "   Fix: use this app's API key, or match package / SHA in admin.")
            }
            is VerifyOutcome.Error ->
              Log.e(TAG, "❌ verify error: ${outcome.message}")
          }
          mainHandler.post { verifyHandler?.invoke(outcome) }
        },
        onFailure = { err ->
          val message = err.message ?: "verify failed"
          Log.e(TAG, "❌ verify error: $message")
          val outcome = VerifyOutcome.Error(message)
          lastVerifyOutcome = outcome
          mainHandler.post { verifyHandler?.invoke(outcome) }
        },
      )
    }
  }

  private fun performDeferredMatch(ctx: Context, key: String, markReported: Boolean) {
    if (!matchInFlight.compareAndSet(false, true)) return

    io.execute {
      try {
        val body = buildMatchBody(ctx)
        val bodyJson = body.toString()
        val url = CliqItHttp.joinUrl(
          CliqItDefaults.SERVER_URL,
          *CliqItDefaults.DEFERRED_MATCH_PATH.split('/').filter { it.isNotEmpty() }.toTypedArray(),
        )

        CliqItHttp.postJson(url, key, bodyJson).fold(
          onSuccess = { response ->
            val outcome = parseMatchOutcome(response.body)
            lastDeferredOutcome = outcome
            if (markReported && outcome is DeferredMatchOutcome.Matched) {
              prefs()?.edit()?.putBoolean(CliqItDefaults.KEY_MATCH_REPORTED, true)?.apply()
            }
            when (outcome) {
              is DeferredMatchOutcome.Matched ->
                Log.i(TAG, "✅ deferred match OK — path=${outcome.info.destinationPath ?: "-"} slug=${outcome.info.slug ?: "-"}")
              is DeferredMatchOutcome.NotMatched ->
                Log.i(TAG, "✅ deferred match finished — notMatched score=${outcome.info.score}")
              is DeferredMatchOutcome.Failed ->
                Log.e(TAG, "❌ deferred match error: ${outcome.error}")
            }
            mainHandler.post { deferredHandler?.invoke(outcome) }
            when (outcome) {
              is DeferredMatchOutcome.Matched -> {
                deliverDeferredOutcome(outcome.info, matched = true)
              }
              is DeferredMatchOutcome.NotMatched -> {
                deliverDeferredOutcome(outcome.info, matched = false)
              }
              is DeferredMatchOutcome.Failed -> {
                deliver(
                  CliqItPayload(
                    url = CliqItDefaults.SERVER_URL,
                    path = "",
                    pathComponents = emptyList(),
                    query = emptyMap(),
                    source = "deferred",
                    isDeferred = true,
                    status = "failed",
                    matched = false,
                    errorMessage = outcome.error,
                  ),
                )
              }
            }
          },
          onFailure = { err ->
            val message = err.message ?: "match failed"
            Log.e(TAG, "❌ deferred match error: $message")
            val outcome = DeferredMatchOutcome.Failed(message)
            lastDeferredOutcome = outcome
            mainHandler.post { deferredHandler?.invoke(outcome) }
            deliver(
              CliqItPayload(
                url = CliqItDefaults.SERVER_URL,
                path = "",
                pathComponents = emptyList(),
                query = emptyMap(),
                source = "deferred",
                isDeferred = true,
                status = "failed",
                matched = false,
                errorMessage = message,
              ),
            )
          },
        )
      } catch (e: Exception) {
        val message = e.message ?: e.toString()
        Log.e(TAG, "❌ deferred match error: $message", e)
        val outcome = DeferredMatchOutcome.Failed(message)
        lastDeferredOutcome = outcome
        mainHandler.post { deferredHandler?.invoke(outcome) }
        deliver(
          CliqItPayload(
            url = CliqItDefaults.SERVER_URL,
            path = "",
            pathComponents = emptyList(),
            query = emptyMap(),
            source = "deferred",
            isDeferred = true,
            status = "failed",
            matched = false,
            errorMessage = message,
          ),
        )
      } finally {
        matchInFlight.set(false)
      }
    }
  }

  private fun deliverDeferredOutcome(info: DeferredMatchInfo, matched: Boolean) {
    val prefs = prefs()
    val alreadyDelivered = prefs?.getBoolean(CliqItDefaults.KEY_DEFERRED_DELIVERED, false) == true
    val navigate = matched &&
      !alreadyDelivered &&
      !receivedDirectThisSession &&
      pendingPayload == null
    val dest = LinkDetails.normalizePath(info.destinationPath)
    val openPath = if (navigate && dest != null) dest else ""
    if (navigate && dest != null) {
      prefs?.edit()?.putBoolean(CliqItDefaults.KEY_DEFERRED_DELIVERED, true)?.apply()
    }
    deliver(
      CliqItPayload(
        url = "${CliqItDefaults.SERVER_URL}${dest ?: "/"}",
        path = openPath,
        pathComponents = openPath.split('/').filter { it.isNotEmpty() },
        query = emptyMap(),
        source = "deferred",
        isDeferred = true,
        status = if (matched) "matched" else "notMatched",
        matched = matched,
        tier = info.tier,
        confidence = info.confidence,
        score = info.score,
        slug = info.slug,
        destinationPath = dest,
      ),
    )
  }

  private fun buildMatchBody(ctx: Context): JSONObject {
    val (level, charging) = CliqItDeviceInfo.battery(ctx)
    // Collect WebView fingerprints before POST (same signals as iOS).
    val web = CliqItWebFingerprint.collect(ctx)
    return JSONObject().apply {
      put("platform", "android")
      put("packageName", CliqItDeviceInfo.packageName(ctx))
      putOpt("androidSha256", CliqItDeviceInfo.androidSha256(ctx))
      put("osVersionMajor", CliqItDeviceInfo.osVersionMajor())
      put("osVersionMajorMinor", CliqItDeviceInfo.osVersionMajorMinor())
      put("deviceModelClass", "android")
      put("deviceName", CliqItDeviceInfo.deviceName())
      put("locale", CliqItDeviceInfo.matchLocale())
      put("timezone", CliqItDeviceInfo.timezone())
      put("screenBucket", CliqItDeviceInfo.screenBucket(ctx))
      put("appOpenAt", System.currentTimeMillis())
      putOpt("connectionType", CliqItDeviceInfo.connectionType(ctx))
      putOpt("batteryLevel", level)
      putOpt("batteryCharging", charging)
      put("languagesOrdered", CliqItDeviceInfo.languagesOrdered())
      put("colorScheme", CliqItDeviceInfo.colorScheme(ctx))
      put("hourCycle", CliqItDeviceInfo.hourCycle())
      putOpt("currency", CliqItDeviceInfo.currencyCode())
      putOpt("regionCode", CliqItDeviceInfo.regionCode())
      put("dynamicTypeSize", CliqItDeviceInfo.fontScale(ctx))
      put("boldText", CliqItDeviceInfo.boldText(ctx))
      put("reduceMotion", CliqItDeviceInfo.reduceMotion(ctx))
      put("increaseContrast", CliqItDeviceInfo.increaseContrast(ctx))
      put("hardwareConcurrency", CliqItDeviceInfo.hardwareConcurrency())
      put("devicePixelRatioBucket", CliqItDeviceInfo.devicePixelRatioBucket(ctx))
      putOpt("clickSessionId", launchClickSessionId)
      web?.clockSkewMs?.let { put("clockSkewMs", it) }
      putOpt("canvasHash", web?.canvasHash)
      putOpt("webglHash", web?.webglHash)
      putOpt("webglVendor", web?.webglVendor)
      putOpt("gpuRenderer", web?.gpuRenderer)
      putOpt("audioFingerprint", web?.audioFingerprint)
    }
  }

  private fun parseMatchOutcome(body: String): DeferredMatchOutcome {
    return try {
      val json = JSONObject(body)
      // Some APIs return { status:false, message:"..." } even with HTTP 200
      if (json.has("status") && !json.optBoolean("status", true) && !json.has("matched")) {
        val msg = CliqItHttp.optString(json, "message") ?: body
        return DeferredMatchOutcome.Failed(msg)
      }
      val info = DeferredMatchInfo(
        matched = json.optBoolean("matched", false),
        tier = CliqItHttp.optString(json, "tier"),
        confidence = when {
          json.has("confidence") && !json.isNull("confidence") ->
            json.opt("confidence")?.toString()
          else -> null
        },
        score = CliqItHttp.optDouble(json, "score"),
        destinationPath = CliqItHttp.optString(json, "destinationPath"),
        slug = CliqItHttp.optString(json, "slug"),
      )
      if (info.matched) DeferredMatchOutcome.Matched(info) else DeferredMatchOutcome.NotMatched(info)
    } catch (e: Exception) {
      DeferredMatchOutcome.Failed(e.message ?: "decode failed")
    }
  }

  private fun fetchLinkDetails(
    key: String,
    uri: Uri,
    slug: String,
    fallback: CliqItPayload,
  ) {
    val ctx = appContext ?: return
    io.execute {
      var url = CliqItHttp.joinUrl(
        CliqItDefaults.SERVER_URL,
        *CliqItDefaults.LINK_LOOKUP_PATH.split('/').filter { it.isNotEmpty() }.toTypedArray(),
        slug,
      )
      url = CliqItHttp.appendIdentityQuery(url, ctx)
      CliqItHttp.get(url, key).fold(
        onSuccess = { response ->
          when (val parsed = parseLinkDetails(response.body)) {
            is LinkLookupResult.Resolved -> {
              lastLinkDetails = parsed.details
              Log.i(TAG, "✅ link lookup OK — path=${parsed.details.resolvedPath ?: "-"} slug=${parsed.details.slug ?: slug}")
              val resolved = resolvedPayload(parsed.details, uri, fallback)
              mainHandler.post {
                linkLookupHandler?.invoke(parsed)
                deliver(resolved ?: fallback)
              }
            }
            is LinkLookupResult.Failed -> {
              Log.e(TAG, "❌ link lookup error: ${parsed.error}")
              mainHandler.post {
                linkLookupHandler?.invoke(parsed)
                deliver(fallback)
              }
            }
          }
        },
        onFailure = { err ->
          val message = err.message ?: "lookup failed"
          Log.e(TAG, "❌ link lookup error: $message")
          mainHandler.post {
            linkLookupHandler?.invoke(LinkLookupResult.Failed(message))
            deliver(fallback)
          }
        },
      )
    }
  }

  private fun parseLinkDetails(body: String): LinkLookupResult {
    return try {
      val root = JSONObject(body)
      if (!root.optBoolean("status", false)) {
        return LinkLookupResult.Failed(CliqItHttp.optString(root, "message") ?: "Link lookup failed")
      }
      val data = root.optJSONObject("data")
        ?: return LinkLookupResult.Failed("Missing data")
      LinkLookupResult.Resolved(
        LinkDetails(
          destination = CliqItHttp.optString(data, "destination"),
          iosDestination = CliqItHttp.optString(data, "iosDestination"),
          androidDestination = CliqItHttp.optString(data, "androidDestination"),
          ogTitle = CliqItHttp.optString(data, "ogTitle"),
          ogDescription = CliqItHttp.optString(data, "ogDescription"),
          ogImage = CliqItHttp.optString(data, "ogImage"),
          ogUrl = CliqItHttp.optString(data, "ogUrl"),
          slug = CliqItHttp.optString(data, "slug"),
          webFallback = CliqItHttp.optString(data, "webFallback"),
          showInterstitial = CliqItHttp.optBool(data, "showInterstitial"),
          isDeepLink = CliqItHttp.optBool(data, "isDeepLink"),
          appleTeamId = CliqItHttp.optString(data, "appleTeamId"),
          iosBundleId = CliqItHttp.optString(data, "iosBundleId"),
          androidPackageName = CliqItHttp.optString(data, "androidPackageName"),
        ),
      )
    } catch (e: Exception) {
      LinkLookupResult.Failed(e.message ?: "Invalid link lookup response")
    }
  }

  private fun resolvedPayload(details: LinkDetails, uri: Uri, fallback: CliqItPayload): CliqItPayload? {
    val path = details.resolvedPath ?: return null
    return CliqItPayload(
      url = uri.toString(),
      path = path,
      pathComponents = path.split('/').filter { it.isNotEmpty() },
      query = fallback.query,
      source = fallback.source,
      isDeferred = false,
    )
  }

  private fun deliver(payload: CliqItPayload) {
    val handler = deepLinkHandler
    if (handler != null) {
      mainHandler.post { handler(payload) }
    } else {
      pendingPayload = payload
    }
  }

  private fun prefs() =
    appContext?.getSharedPreferences(CliqItDefaults.PREFS, Context.MODE_PRIVATE)

  private fun slugFrom(uri: Uri): String? {
    val last = uri.pathSegments.lastOrNull()?.takeIf { it.isNotEmpty() }
    if (last != null) return last
    return uri.host?.takeIf { it.isNotEmpty() }
  }

  private fun captureClickSessionId(uri: Uri) {
    if (launchClickSessionId != null) return
    for (key in listOf("session", "clickSessionId", "click_session_id")) {
      val v = uri.getQueryParameter(key)?.trim()
      if (!v.isNullOrEmpty()) {
        launchClickSessionId = v
        return
      }
    }
  }

  private fun detectSource(uri: Uri): String {
    val scheme = uri.scheme?.lowercase().orEmpty()
    return when {
      scheme == "http" || scheme == "https" -> "universalLink"
      scheme.isNotEmpty() -> "customScheme"
      else -> "unknown"
    }
  }

  /** Only `*.theblockyapp.com` https hosts, or custom schemes registered by this app. */
  private fun isAllowedUrl(uri: Uri): Boolean {
    val scheme = uri.scheme?.lowercase().orEmpty()
    return when {
      scheme == "http" || scheme == "https" -> {
        val host = uri.host?.lowercase() ?: return false
        isAllowedHost(host)
      }
      scheme.isNotEmpty() -> isRegisteredScheme(scheme)
      else -> false
    }
  }

  private fun isAllowedHost(host: String): Boolean {
    val root = CliqItDefaults.ALLOWED_LINK_DOMAIN.lowercase()
    return host == root || host.endsWith(".$root")
  }

  private fun isRegisteredScheme(scheme: String): Boolean {
    val ctx = appContext ?: return false
    return try {
      val probe = android.content.Intent(
        android.content.Intent.ACTION_VIEW,
        Uri.parse("$scheme://cliqit-allow-check"),
      ).setPackage(ctx.packageName)
      ctx.packageManager.queryIntentActivities(probe, 0).isNotEmpty()
    } catch (_: Exception) {
      false
    }
  }

  private fun parsePayload(uri: Uri, source: String, isDeferred: Boolean): CliqItPayload {
    val path = uri.path?.takeIf { it.isNotEmpty() } ?: "/"
    val components = uri.pathSegments.filter { it.isNotEmpty() }
    val query = mutableMapOf<String, String>()
    uri.queryParameterNames.forEach { name ->
      uri.getQueryParameter(name)?.let { query[name] = it }
    }
    return CliqItPayload(
      url = uri.toString(),
      path = path,
      pathComponents = components,
      query = query,
      source = source,
      isDeferred = isDeferred,
    )
  }
}
