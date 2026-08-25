package com.cliqit.sdk

object CliqItDefaults {
  const val SERVER_URL = "https://api.theblockyapp.com"
  const val DEFERRED_MATCH_PATH = "api/v1/sdk/app/match"
  const val LINK_LOOKUP_PATH = "api/v1/sdk/link"
  const val VERIFY_PATH = "api/v1/sdk/verify"
  const val API_KEY_HEADER = "x-api-key"
  const val MAX_RETRY = 3
  const val RETRY_INITIAL_DELAY_MS = 500L

  const val PREFS = "cliqit_sdk"
  const val KEY_MATCH_REPORTED = "com.cliqit.deferred.match.reported"
  const val KEY_DEFERRED_DELIVERED = "com.cliqit.deferred.delivered"
  /** When no explicit domain is configured, only this host + subdomains are accepted. */
  const val ALLOWED_LINK_DOMAIN = "theblockyapp.com"
}
