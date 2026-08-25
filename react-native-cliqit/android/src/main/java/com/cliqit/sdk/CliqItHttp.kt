package com.cliqit.sdk

import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

internal object CliqItHttp {
  data class Response(val statusCode: Int, val body: String)

  fun get(url: String, apiKey: String): Result<Response> =
    request(url, "GET", apiKey, null)

  fun postJson(url: String, apiKey: String, jsonBody: String): Result<Response> =
    request(url, "POST", apiKey, jsonBody)

  private fun request(
    url: String,
    method: String,
    apiKey: String,
    jsonBody: String?,
  ): Result<Response> {
    var lastError = "Request failed"
    repeat(CliqItDefaults.MAX_RETRY) { attempt ->
      if (attempt > 0) {
        Thread.sleep(CliqItDefaults.RETRY_INITIAL_DELAY_MS * (1L shl (attempt - 1)))
      }
      try {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
          requestMethod = method
          connectTimeout = 15_000
          readTimeout = 20_000
          setRequestProperty(CliqItDefaults.API_KEY_HEADER, apiKey)
          setRequestProperty("Accept", "application/json")
          if (jsonBody != null) {
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
          }
        }
        if (jsonBody != null) {
          OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(jsonBody) }
        }
        val code = conn.responseCode
        val stream = if (code in 200..299) conn.inputStream else conn.errorStream
        val body = stream?.let { BufferedReader(InputStreamReader(it, Charsets.UTF_8)).readText() }.orEmpty()
        conn.disconnect()

        if (code in 200..299) {
          return Result.success(Response(code, body))
        }
        lastError = "Request failed ($code): ${body.ifEmpty { "empty" }}"
        if (code == 408 || code == 429 || code in 500..599) {
          // retry
        } else {
          return Result.failure(Exception(lastError))
        }
      } catch (e: Exception) {
        lastError = e.message ?: "Request failed"
      }
    }
    return Result.failure(Exception(lastError))
  }

  fun joinUrl(base: String, vararg parts: String): String {
    val trimmedBase = base.trimEnd('/')
    val path = parts.joinToString("/") { it.trim('/') }
    return "$trimmedBase/$path"
  }

  /** Append platform identity query params (same fields as verify / match body). */
  fun appendIdentityQuery(url: String, context: android.content.Context): String {
    val sep = if (url.contains('?')) '&' else '?'
    val platform = "platform=android"
    val packageName = "packageName=${java.net.URLEncoder.encode(CliqItDeviceInfo.packageName(context), Charsets.UTF_8.name())}"
    val sha = CliqItDeviceInfo.androidSha256(context)?.let {
      "&androidSha256=${java.net.URLEncoder.encode(it, Charsets.UTF_8.name())}"
    }.orEmpty()
    return "$url$sep$platform&$packageName$sha"
  }

  fun optString(obj: JSONObject?, key: String): String? {
    if (obj == null || !obj.has(key) || obj.isNull(key)) return null
    val v = obj.optString(key, "")
    return v.takeIf { it.isNotEmpty() && !it.equals("null", ignoreCase = true) }
  }

  fun optBool(obj: JSONObject?, key: String): Boolean? {
    if (obj == null || !obj.has(key) || obj.isNull(key)) return null
    return obj.optBoolean(key)
  }

  fun optDouble(obj: JSONObject?, key: String): Double? {
    if (obj == null || !obj.has(key) || obj.isNull(key)) return null
    return obj.optDouble(key).takeUnless { it.isNaN() }
  }
}
