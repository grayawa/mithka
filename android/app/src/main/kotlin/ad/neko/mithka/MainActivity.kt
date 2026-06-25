package ad.neko.mithka

import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var callMedia: CallMediaPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val plugin = CallMediaPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        callMedia = plugin
        // Embed call video surfaces (TextureViewRenderer) into the widget tree.
        flutterEngine.platformViewsController.registry
            .registerViewFactory("mithka/video_view", VideoViewFactory(plugin))

        // App info for the GitHub-release update checker: the device's supported
        // ABIs (preference-ordered, so we can match the right per-ABI APK asset)
        // and the installed version name (the semver compared to the latest tag).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mithka/app_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "info") {
                    val pkg = packageManager.getPackageInfo(packageName, 0)
                    result.success(
                        mapOf(
                            "abis" to Build.SUPPORTED_ABIS.toList(),
                            "version" to (pkg.versionName ?: ""),
                        ),
                    )
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mithka/clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method != "readImage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = clipboard.primaryClip
                if (clip == null || clip.itemCount == 0) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val uri = clip.getItemAt(0).uri
                if (uri == null) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val mimeType = contentResolver.getType(uri)
                    ?: clip.description?.getMimeType(0)
                    ?: "image/png"
                if (!mimeType.startsWith("image/")) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                try {
                    contentResolver.openInputStream(uri).use { input ->
                        if (input == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val output = ByteArrayOutputStream()
                        input.copyTo(output)
                        result.success(
                            mapOf(
                                "mimeType" to mimeType,
                                "data" to output.toByteArray(),
                            ),
                        )
                    }
                } catch (e: Exception) {
                    result.error("clipboard_unavailable", e.message, null)
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callMedia?.dispose()
        callMedia = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
