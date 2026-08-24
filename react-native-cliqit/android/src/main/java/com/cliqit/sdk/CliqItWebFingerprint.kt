package com.cliqit.sdk

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.webkit.WebViewClient
import org.json.JSONObject
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Hidden WebView probe — same signals as iOS CliqItWebFingerprintCollector
 * (canvas / WebGL / audio / clock skew). Runs on main thread; blocks caller briefly.
 */
internal object CliqItWebFingerprint {
  data class Result(
    val canvasHash: String?,
    val webglHash: String?,
    val webglVendor: String?,
    val gpuRenderer: String?,
    val audioFingerprint: String?,
    val clockSkewMs: Int?,
  )

  private val htmlPage = """
    <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head><body>
    <canvas id="c" width="280" height="80"></canvas>
    <script>
    function __cliqItHash(str) {
      var h = 2166136261 >>> 0;
      for (var i = 0; i < str.length; i++) {
        h ^= str.charCodeAt(i);
        h = Math.imul(h, 16777619) >>> 0;
      }
      return (h >>> 0).toString(16);
    }
    function __cliqItCanvas() {
      try {
        var c = document.getElementById('c') || document.createElement('canvas');
        c.width = 280; c.height = 80;
        var ctx = c.getContext('2d');
        if (!ctx) return null;
        ctx.textBaseline = 'alphabetic';
        ctx.fillStyle = '#f60';
        ctx.fillRect(10, 1, 140, 24);
        var grad = ctx.createLinearGradient(0, 0, 200, 60);
        grad.addColorStop(0, '#069');
        grad.addColorStop(1, 'rgba(102,204,0,0.7)');
        ctx.fillStyle = grad;
        ctx.font = '16px Arial';
        ctx.fillText('CliqIt,fp', 2, 20);
        ctx.font = '14px "Courier New"';
        ctx.fillText('mmmmmmmmmlli', 2, 42);
        ctx.font = '12px Georgia';
        ctx.fillText('Cwm fjord bank', 2, 60);
        ctx.beginPath();
        ctx.arc(220, 40, 18, 0, Math.PI * 2);
        ctx.strokeStyle = '#c33';
        ctx.stroke();
        return __cliqItHash(c.toDataURL());
      } catch (e) { return null; }
    }
    function __cliqItWebGL() {
      try {
        var c = document.createElement('canvas');
        c.width = 16; c.height = 16;
        var gl = c.getContext('webgl') || c.getContext('experimental-webgl');
        if (!gl) return { hash: null, vendor: null, renderer: null };
        var dbg = gl.getExtension('WEBGL_debug_renderer_info');
        var vendor = dbg ? String(gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL)) : String(gl.getParameter(gl.VENDOR));
        var renderer = dbg ? String(gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL)) : String(gl.getParameter(gl.RENDERER));
        var params = [
          String(gl.getParameter(gl.VERSION) || ''),
          String(gl.getParameter(gl.SHADING_LANGUAGE_VERSION) || ''),
          vendor || '',
          renderer || '',
          String(gl.getParameter(gl.MAX_TEXTURE_SIZE) || ''),
          String(gl.getParameter(gl.MAX_RENDERBUFFER_SIZE) || ''),
          (gl.getSupportedExtensions() || []).join(',')
        ].join('|');
        return { hash: __cliqItHash(params), vendor: vendor || null, renderer: renderer || null };
      } catch (e) {
        return { hash: null, vendor: null, renderer: null };
      }
    }
    function __cliqItAudio() {
      return new Promise(function(resolve) {
        var settled = false;
        function done(v) { if (settled) return; settled = true; resolve(v); }
        try {
          var AC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
          if (!AC) { done(null); return; }
          var ctx = new AC(1, 44100, 44100);
          var osc = ctx.createOscillator();
          var comp = ctx.createDynamicsCompressor();
          osc.type = 'triangle';
          osc.frequency.value = 10000;
          comp.threshold.value = -50;
          comp.knee.value = 40;
          comp.ratio.value = 12;
          comp.attack.value = 0;
          comp.release.value = 0.25;
          osc.connect(comp);
          comp.connect(ctx.destination);
          osc.start(0);
          ctx.oncomplete = function(ev) {
            try {
              var data = ev.renderedBuffer.getChannelData(0);
              var sum = 0;
              for (var i = 4500; i < 5000; i++) sum += Math.abs(data[i]);
              done(__cliqItHash(String(sum)));
            } catch (e) { done(null); }
          };
          ctx.startRendering();
          setTimeout(function() { done(null); }, 700);
        } catch (e) { done(null); }
      });
    }
    window.__cliqItCollectFingerprint = async function() {
      var gl = __cliqItWebGL();
      var skew = null;
      try {
        if (window.performance && typeof performance.now === 'function' && performance.timeOrigin) {
          skew = Date.now() - (performance.timeOrigin + performance.now());
        }
      } catch (e) {}
      var audio = await __cliqItAudio();
      return {
        canvasHash: __cliqItCanvas(),
        webglHash: gl.hash,
        webglVendor: gl.vendor,
        webglRenderer: gl.renderer,
        audioHash: audio,
        clockSkewMs: skew
      };
    };
    </script></body></html>
  """.trimIndent()

  @SuppressLint("SetJavaScriptEnabled")
  fun collect(context: Context, timeoutMs: Long = 3500L): Result? {
    val latch = CountDownLatch(1)
    val holder = AtomicReference<Result?>(null)
    val appCtx = context.applicationContext

    Handler(Looper.getMainLooper()).post {
      var webView: WebView? = null
      try {
        webView = WebView(appCtx).apply {
          settings.javaScriptEnabled = true
          settings.domStorageEnabled = false
          // Keep off-screen; do not attach to a window.
          webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
              view?.evaluateJavascript(
                "(async function(){ try { return JSON.stringify(await window.__cliqItCollectFingerprint()); } catch(e) { return null; } })()",
              ) { value ->
                holder.set(parseJsResult(value))
                try {
                  view.destroy()
                } catch (_: Exception) {
                }
                latch.countDown()
              }
            }
          }
          loadDataWithBaseURL(
            "https://localhost/",
            htmlPage,
            "text/html",
            "UTF-8",
            null,
          )
        }
      } catch (_: Exception) {
        try {
          webView?.destroy()
        } catch (_: Exception) {
        }
        latch.countDown()
      }
    }

    latch.await(timeoutMs, TimeUnit.MILLISECONDS)
    return holder.get()
  }

  private fun parseJsResult(raw: String?): Result? {
    if (raw.isNullOrBlank() || raw == "null") return null
    // evaluateJavascript wraps strings in JSON quotes
    val unquoted = try {
      org.json.JSONTokener(raw).nextValue()?.let { v ->
        when (v) {
          is String -> v
          else -> raw.trim().removeSurrounding("\"")
            .replace("\\\"", "\"")
            .replace("\\\\", "\\")
        }
      } ?: return null
    } catch (_: Exception) {
      raw.trim().removeSurrounding("\"")
        .replace("\\\"", "\"")
        .replace("\\\\", "\\")
    }
    return try {
      val json = JSONObject(unquoted)
      fun opt(key: String): String? =
        if (!json.has(key) || json.isNull(key)) null
        else json.optString(key, "").takeIf { it.isNotEmpty() && it != "null" }

      val skew = when {
        !json.has("clockSkewMs") || json.isNull("clockSkewMs") -> null
        else -> json.optDouble("clockSkewMs").takeUnless { it.isNaN() }?.toInt()
      }
      Result(
        canvasHash = opt("canvasHash"),
        webglHash = opt("webglHash"),
        webglVendor = opt("webglVendor"),
        gpuRenderer = opt("webglRenderer"),
        audioFingerprint = opt("audioHash"),
        clockSkewMs = skew,
      )
    } catch (_: Exception) {
      null
    }
  }
}
