package com.cliqit.sdk

/** Mirrors iOS `CliqItLinkField`. */
object LinkField {
  const val destination = "destination"
  const val iosDestination = "iosDestination"
  const val androidDestination = "androidDestination"
  const val ogTitle = "ogTitle"
  const val ogDescription = "ogDescription"
  const val ogImage = "ogImage"
  const val ogUrl = "ogUrl"
  const val slug = "slug"
  const val webFallback = "webFallback"
  const val showInterstitial = "showInterstitial"
  const val isDeepLink = "isDeepLink"
  const val appleTeamId = "appleTeamId"
  const val iosBundleId = "iosBundleId"
  const val androidPackageName = "androidPackageName"
  const val resolvedPath = "resolvedPath"
}

data class CliqItPayload(
  val url: String,
  val path: String,
  val pathComponents: List<String>,
  val query: Map<String, String>,
  val source: String,
  val isDeferred: Boolean,
  /** opened | matched | notMatched | failed | alreadyReported */
  val status: String = "opened",
  val matched: Boolean? = null,
  val tier: String? = null,
  val confidence: String? = null,
  val score: Double? = null,
  val slug: String? = null,
  val destinationPath: String? = path.ifEmpty { null },
  val errorMessage: String? = null,
) {
  val shouldNavigate: Boolean
    get() = path.isNotEmpty() && (status == "opened" || status == "matched" || status == "lookupFailed")
}

data class DeferredMatchInfo(
  val matched: Boolean,
  val tier: String?,
  val confidence: String?,
  val score: Double?,
  val destinationPath: String?,
  val slug: String?,
)

sealed class DeferredMatchOutcome {
  data class Matched(val info: DeferredMatchInfo) : DeferredMatchOutcome()
  data class NotMatched(val info: DeferredMatchInfo) : DeferredMatchOutcome()
  data class Failed(val error: String) : DeferredMatchOutcome()
}

data class LinkDetails(
  val destination: String?,
  val iosDestination: String?,
  val androidDestination: String?,
  val ogTitle: String?,
  val ogDescription: String?,
  val ogImage: String?,
  val ogUrl: String?,
  val slug: String?,
  val webFallback: String?,
  val showInterstitial: Boolean?,
  val isDeepLink: Boolean?,
  val appleTeamId: String?,
  val iosBundleId: String?,
  val androidPackageName: String?,
) {
  /** Android: `androidDestination` ?? `destination`. */
  val resolvedPath: String?
    get() = normalizePath(androidDestination) ?: normalizePath(destination)

  fun field(key: String): String? = when (key) {
    LinkField.destination -> destination
    LinkField.iosDestination -> iosDestination
    LinkField.androidDestination -> androidDestination
    LinkField.ogTitle -> ogTitle
    LinkField.ogDescription -> ogDescription
    LinkField.ogImage -> ogImage
    LinkField.ogUrl -> ogUrl
    LinkField.slug -> slug
    LinkField.webFallback -> webFallback
    LinkField.showInterstitial -> showInterstitial?.toString()
    LinkField.isDeepLink -> isDeepLink?.toString()
    LinkField.appleTeamId -> appleTeamId
    LinkField.iosBundleId -> iosBundleId
    LinkField.androidPackageName -> androidPackageName
    LinkField.resolvedPath -> resolvedPath
    else -> null
  }

  companion object {
    fun normalizePath(raw: String?): String? {
      var value = raw?.trim().orEmpty()
      if (value.isEmpty() || value.equals("null", ignoreCase = true)) return null
      if (!value.startsWith("/")) value = "/$value"
      return value
    }
  }
}

sealed class VerifyOutcome {
  data class Passed(val result: VerifyResult) : VerifyOutcome()
  data class Mismatched(val result: VerifyResult) : VerifyOutcome()
  data class Error(val message: String) : VerifyOutcome()
}

data class VerifyCheck(
  val actual: String?,
  val expected: String?,
  val match: Boolean,
)

data class VerifyResult(
  val ok: Boolean,
  val appId: String?,
  val appName: String?,
  val checks: Map<String, VerifyCheck>,
  val rawJSON: String,
) {
  val failedChecks: List<Pair<String, VerifyCheck>>
    get() = checks.filter { !it.value.match }.toList().sortedBy { it.first }

  val mismatchMessage: String
    get() {
      if (ok) return "Verify OK"
      if (failedChecks.isEmpty()) return "Verify failed (ok=false)"
      return failedChecks.joinToString("; ") { (field, check) ->
        "$field: actual=${check.actual ?: "-"} expected=${check.expected ?: "-"}"
      }
    }
}

sealed class LinkLookupResult {
  data class Resolved(val details: LinkDetails) : LinkLookupResult()
  data class Failed(val error: String) : LinkLookupResult()
}
