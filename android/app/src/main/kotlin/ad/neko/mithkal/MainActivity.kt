package ad.neko.mithkal

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var callMedia: CallMediaPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callMedia = CallMediaPlugin(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        callMedia?.dispose()
        callMedia = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
