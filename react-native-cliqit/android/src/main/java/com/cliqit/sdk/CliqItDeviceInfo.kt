package com.cliqit.sdk

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import java.security.MessageDigest
import java.util.Currency
import java.util.Locale
import java.util.TimeZone

internal object CliqItDeviceInfo {
  fun osVersionMajor(): String =
    Build.VERSION.RELEASE.substringBefore('.').ifEmpty { Build.VERSION.SDK_INT.toString() }

  fun osVersionMajorMinor(): String {
    val parts = Build.VERSION.RELEASE.split('.')
    return when {
      parts.size >= 2 -> "${parts[0]}.${parts[1]}"
      parts.isNotEmpty() -> parts[0]
      else -> Build.VERSION.SDK_INT.toString()
    }
  }

  fun deviceName(): String = Build.MODEL ?: "unknown"

  fun matchLocale(): String =
    Locale.getDefault().toLanguageTag().ifEmpty { Locale.getDefault().toString().replace('_', '-') }

  fun languagesOrdered(): String {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      val list = android.os.LocaleList.getDefault()
      (0 until list.size()).joinToString(",") { i -> list[i].toLanguageTag() }
        .ifEmpty { Locale.getDefault().toLanguageTag() }
    } else {
      Locale.getDefault().toLanguageTag()
    }
  }

  fun boldText(context: Context): Boolean {
    return try {
      android.provider.Settings.Secure.getInt(
        context.contentResolver,
        "accessibility_bold_text",
        0,
      ) == 1
    } catch (_: Exception) {
      false
    }
  }

  fun reduceMotion(context: Context): Boolean {
    return try {
      val scale = android.provider.Settings.Global.getFloat(
        context.contentResolver,
        android.provider.Settings.Global.TRANSITION_ANIMATION_SCALE,
        1f,
      )
      scale == 0f
    } catch (_: Exception) {
      false
    }
  }

  fun increaseContrast(context: Context): Boolean {
    return try {
      android.provider.Settings.Secure.getInt(
        context.contentResolver,
        "high_text_contrast_enabled",
        0,
      ) == 1
    } catch (_: Exception) {
      false
    }
  }

  fun timezone(): String = TimeZone.getDefault().id

  fun screenBucket(context: Context): String {
    val metrics = DisplayMetrics()
    @Suppress("DEPRECATION")
    (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.getMetrics(metrics)
    val minSide = minOf(metrics.widthPixels, metrics.heightPixels).toFloat() / metrics.density
    val maxSide = maxOf(metrics.widthPixels, metrics.heightPixels).toFloat() / metrics.density
    return when {
      minSide >= 600 -> "tablet"
      maxSide >= 800 -> "large"
      maxSide >= 700 -> "medium"
      else -> "small"
    }
  }

  fun colorScheme(context: Context): String {
    val night = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return if (night == Configuration.UI_MODE_NIGHT_YES) "dark" else "light"
  }

  fun hourCycle(): String {
    val pattern = android.text.format.DateFormat.getBestDateTimePattern(Locale.getDefault(), "j")
    return if (pattern.contains('a')) "h12" else "h24"
  }

  fun currencyCode(): String? = try {
    Currency.getInstance(Locale.getDefault()).currencyCode
  } catch (_: Exception) {
    null
  }

  fun regionCode(): String? = Locale.getDefault().country.takeIf { it.isNotEmpty() }

  /// Matches iOS / web: `"high"` (≥2×) or `"standard"`.
  fun devicePixelRatioBucket(context: Context): String {
    val density = context.resources.displayMetrics.density
    return if (density >= 2.0f) "high" else "standard"
  }

  fun battery(context: Context): Pair<Double?, Boolean?> {
    val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
      ?: return null to null
    val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
    val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
    val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
    val pct = if (level >= 0 && scale > 0) level.toDouble() / scale.toDouble() else null
    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
      status == BatteryManager.BATTERY_STATUS_FULL
    return pct to charging
  }

  fun connectionType(context: Context): String? {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return null
    val network = cm.activeNetwork ?: return null
    val caps = cm.getNetworkCapabilities(network) ?: return null
    return when {
      caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
      caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
      else -> "other"
    }
  }

  fun hardwareConcurrency(): Int = Runtime.getRuntime().availableProcessors()

  fun fontScale(context: Context): String {
    val scale = context.resources.configuration.fontScale
    return when {
      scale <= 0.85f -> "S"
      scale <= 1.0f -> "M"
      scale <= 1.15f -> "L"
      scale <= 1.3f -> "XL"
      else -> "XXL"
    }
  }

  fun packageName(context: Context): String = context.packageName

  /** Signing cert SHA-256, colon-separated uppercase (same style as keytool / assetlinks). */
  fun androidSha256(context: Context): String? {
    return try {
      val pm = context.packageManager
      val packageName = context.packageName
      val signatures: Array<android.content.pm.Signature> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
          pm.getPackageInfo(
            packageName,
            PackageManager.PackageInfoFlags.of(PackageManager.GET_SIGNING_CERTIFICATES.toLong()),
          )
        } else {
          @Suppress("DEPRECATION")
          pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
        }
        val signingInfo = info.signingInfo ?: return null
        if (signingInfo.hasMultipleSigners()) {
          signingInfo.apkContentsSigners
        } else {
          signingInfo.signingCertificateHistory
        }
      } else {
        @Suppress("DEPRECATION")
        pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
      } ?: return null

      val cert = signatures.firstOrNull()?.toByteArray() ?: return null
      val digest = MessageDigest.getInstance("SHA-256").digest(cert)
      digest.joinToString(":") { b -> "%02X".format(b) }
    } catch (e: Exception) {
      null
    }
  }
}
