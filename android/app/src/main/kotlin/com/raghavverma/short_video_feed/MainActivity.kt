package com.raghavverma.short_video_feed

import android.net.TrafficStats
import android.os.Bundle
import android.os.Process
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A full-screen video feed should not dim mid-video. The flag only
        // applies while this window is visible. iOS gets the same from
        // video_player's preventsDisplaySleepDuringVideoPlayback (default on).
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Bytes this app has received, for the playback HUD and the
        // benchmark: what preloading costs in data, not only in memory.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "short_video_feed/diagnostics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "uidRxBytes" -> {
                        val bytes = TrafficStats.getUidRxBytes(Process.myUid())
                        result.success(if (bytes == TrafficStats.UNSUPPORTED.toLong()) null else bytes)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
