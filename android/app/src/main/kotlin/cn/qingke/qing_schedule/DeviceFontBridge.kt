package cn.qingke.qing_schedule

import android.app.Activity
import android.graphics.Paint
import android.graphics.text.TextRunShaper
import android.os.Build
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Reads the fonts Android actually chooses for a themed TextView. */
class DeviceFontBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.qingke.qing_schedule/fonts")
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var alive = true

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT < 31) {
                result.success(null)
            } else {
                try {
                    // Creating the view on the UI thread lets vendor theme hooks
                    // choose their current font, including Chinese fallback.
                    val view = TextView(activity).apply { text = "课程周数 Aa0123" }
                    view.measure(0, 0)
                    val paint = Paint(view.paint)
                    val previous = call.argument<String>("signature")
                    worker.execute {
                        try {
                            val fonts = linkedMapOf<String, Map<String, Any>>()
                            var total = 0
                            for (sample in listOf("Aa0123", "课程周数教师地点九月")) {
                                val glyphs = TextRunShaper.shapeTextRun(sample, 0, sample.length,
                                    0, sample.length, 0f, 0f, false, paint)
                                for (i in 0 until glyphs.glyphCount()) {
                                    val font = glyphs.getFont(i)
                                    val key = "${font.hashCode()}:${font.ttcIndex}"
                                    if (fonts.containsKey(key)) continue
                                    val buffer = font.buffer.duplicate().apply { rewind() }
                                    if (buffer.remaining() > 96 * 1024 * 1024) continue
                                    total += buffer.remaining()
                                    if (total > 128 * 1024 * 1024 || fonts.size >= 4) break
                                    val bytes = ByteArray(buffer.remaining())
                                    buffer.get(bytes)
                                    fonts[key] = mapOf("bytes" to bytes, "index" to font.ttcIndex)
                                }
                            }
                            val digest = MessageDigest.getInstance("SHA-256")
                            for (font in fonts.values) {
                                digest.update(font["bytes"] as ByteArray)
                                digest.update((font["index"] as Int).toByte())
                            }
                            val signature = digest.digest().joinToString("") { "%02x".format(it) }
                            activity.runOnUiThread {
                                if (alive) result.success(if (fonts.isEmpty()) null else if (signature == previous)
                                    mapOf("unchanged" to true) else mapOf("signature" to signature, "fonts" to fonts.values.toList()))
                            }
                        } catch (_: Exception) {
                            activity.runOnUiThread { if (alive) result.error("FONT_UNAVAILABLE", "当前字体不可读取", null) }
                        }
                    }
                } catch (_: Exception) { result.error("FONT_UNAVAILABLE", "当前字体不可读取", null) }
            }
        }
    }

    fun changed() { if (alive) channel.invokeMethod("changed", null) }
    fun dispose() { alive = false; channel.setMethodCallHandler(null); worker.shutdown() }
}
