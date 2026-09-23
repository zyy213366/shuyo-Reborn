package cn.qingke.qing_schedule

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity() {
    private var deviceFonts: DeviceFontBridge? = null
    private val io = Executors.newSingleThreadExecutor()
    private val readsInFlight = AtomicInteger(0)
    private val pending = ArrayDeque<Map<String, String>>()
    private var channel: MethodChannel? = null
    private var picker: MethodChannel.Result? = null
    private var alive = true
    private val maxBytes = 2 * 1024 * 1024
    private val pickRequest = 8201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceFonts = DeviceFontBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.qingke.qing_schedule/files")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    val events = pending.toList()
                    pending.clear()
                    result.success(events)
                }
                "pickFile" -> {
                    if (picker != null) {
                        result.error("BUSY", "请先完成当前文件选择", null)
                    } else {
                        picker = result
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                            }
                            startActivityForResult(intent, pickRequest)
                        } catch (e: Exception) {
                            picker = null
                            result.error("PICK_FAILED", "无法打开系统文件选择器", null)
                        }
                    }
                }
                "shareFile" -> {
                    val text = call.argument<String>("text")
                    val name = call.argument<String>("name") ?: "课表"
                    if (text == null || text.toByteArray(StandardCharsets.UTF_8).size > maxBytes) {
                        result.error("INVALID", "课表文件为空或超过 2 MB", null)
                    } else io.execute {
                        try {
                            val directory = File(cacheDir, "shared_schedules").apply { mkdirs() }
                            val file = File(directory, "课表_${System.currentTimeMillis()}.shuyoschedule.json")
                            file.writeText(text, StandardCharsets.UTF_8)
                            runOnUiThread {
                                if (alive) {
                                    try {
                                        val uri = FileProvider.getUriForFile(this, "$packageName.shared", file)
                                        val intent = Intent(Intent.ACTION_SEND).apply {
                                            type = "application/json"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            putExtra(Intent.EXTRA_SUBJECT, name)
                                            clipData = ClipData.newUri(contentResolver, name, uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        startActivity(Intent.createChooser(intent, "分享课表"))
                                        result.success(null)
                                    } catch (e: Exception) { result.error("SHARE_FAILED", "无法打开系统分享菜单", null) }
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread { if (alive) result.error("WRITE_FAILED", "无法生成分享文件，请检查存储空间", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState?.getBoolean("share_handled") != true) receive(intent)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("share_handled", true)
        super.onSaveInstanceState(outState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent) {
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            else -> return
        }
        if (uri == null) { enqueue(mapOf("error" to "请分享课表文件，而不是图片或普通文字")); return }
        if (readsInFlight.incrementAndGet() > 4) {
            readsInFlight.decrementAndGet()
            enqueue(mapOf("error" to "一次最多接收四个课表，请完成导入后重新打开其余文件"))
            return
        }
        io.execute {
            val event = try { mapOf("text" to readDocument(uri)) }
            catch (e: Exception) { mapOf("error" to (e.message ?: "无法读取课表文件")) }
            finally { readsInFlight.decrementAndGet() }
            runOnUiThread { if (alive) enqueue(event) }
        }
    }

    private fun enqueue(event: Map<String, String>) {
        if (pending.size < 4) pending.addLast(event)
        channel?.invokeMethod("pending", null)
    }

    private fun readDocument(uri: Uri): String {
        require(uri.scheme == "content") { "请通过系统文件选择器或聊天应用打开课表文件" }
        val bytes = contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size() + count <= maxBytes) { "课表文件超过 2 MB" }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: throw IllegalArgumentException("无法读取文件，请重新选择")
        require(bytes.isNotEmpty()) { "课表文件是空的" }
        return StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes)).toString().removePrefix("\uFEFF")
    }

    @Deprecated("Activity result API retained for FlutterActivity integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val callback = picker ?: return
        picker = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) { callback.success(null); return }
        io.execute {
            try {
                val text = readDocument(uri)
                runOnUiThread { if (alive) callback.success(text) }
            } catch (e: Exception) {
                runOnUiThread { if (alive) callback.error("READ_FAILED", e.message ?: "无法读取文件", null) }
            }
        }
    }

    override fun onDestroy() {
        deviceFonts?.dispose()
        alive = false
        picker = null
        channel?.setMethodCallHandler(null)
        io.shutdown()
        super.onDestroy()
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        deviceFonts?.changed()
    }
}
