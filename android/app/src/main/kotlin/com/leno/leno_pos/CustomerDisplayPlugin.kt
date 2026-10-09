package com.leno.leno_pos

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.Display
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Màn hình khách trên màn hình phụ (màn hình thứ hai của máy POS, màn hình HDMI, hoặc màn hình
 * giả lập "Simulate secondary displays"): chạy một Flutter engine riêng với điểm vào
 * `customerDisplayMain` (lib/main.dart) bên trong Android Presentation.
 *
 * Kênh "leno/customer_display" (ứng dụng chính -> Android): status, setEnabled, content, snapshot.
 * Kênh "leno/customer_display/view" (Android <-> màn hình khách): content, snapshot, ready.
 */
class CustomerDisplayPlugin(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, DisplayManager.DisplayListener {

    companion object {
        private const val TAG = "CustomerDisplay"
    }

    private val channel = MethodChannel(messenger, "leno/customer_display")
    private val displays = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val main = Handler(Looper.getMainLooper())

    private var enabled = false
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var presentation: Presentation? = null
    private var viewChannel: MethodChannel? = null

    // Nội dung mới nhất — gửi lại khi màn hình khách (re)khởi động.
    private var lastContent: String? = null
    private var lastSnapshot: String? = null

    init {
        channel.setMethodCallHandler(this)
        displays.registerDisplayListener(this, main)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        displays.unregisterDisplayListener(this)
        hide()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "setEnabled" -> {
                enabled = call.arguments as? Boolean ?: false
                if (enabled) show() else hide()
                result.success(null)
            }
            "content" -> {
                lastContent = call.arguments as? String
                lastContent?.let { viewChannel?.invokeMethod("content", it) }
                result.success(null)
            }
            "snapshot" -> {
                lastSnapshot = call.arguments as? String
                lastSnapshot?.let { viewChannel?.invokeMethod("snapshot", it) }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Màn hình phụ dùng được để trình chiếu (bỏ qua màn hình chính). */
    private fun target(): Display? =
        displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }

    @Suppress("DEPRECATION")
    private fun status(): Map<String, Any?> {
        val d = presentation?.display ?: target()
            ?: return mapOf("available" to false, "showing" to false)
        val metrics = DisplayMetrics()
        d.getRealMetrics(metrics)
        return mapOf(
            "available" to true,
            "name" to d.name,
            "width" to metrics.widthPixels,
            "height" to metrics.heightPixels,
            "showing" to (presentation?.isShowing == true),
        )
    }

    private fun show() {
        if (presentation?.isShowing == true) return
        val display = target() ?: return

        val eng = FlutterEngine(activity)
        val loader = FlutterInjector.instance().flutterLoader()
        eng.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "customerDisplayMain")
        )
        val vc = MethodChannel(eng.dartExecutor.binaryMessenger, "leno/customer_display/view")
        vc.setMethodCallHandler { c, r ->
            if (c.method == "ready") {
                lastContent?.let { vc.invokeMethod("content", it) }
                lastSnapshot?.let { vc.invokeMethod("snapshot", it) }
            }
            r.success(null)
        }

        val p = object : Presentation(activity, display) {
            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                val view = FlutterView(context)
                view.attachToFlutterEngine(eng)
                flutterView = view
                setContentView(view)
            }
        }
        try {
            p.show()
        } catch (e: WindowManager.InvalidDisplayException) {
            Log.w(TAG, "Không mở được màn hình phụ: ${e.message}")
            eng.destroy()
            return
        }
        eng.lifecycleChannel.appIsResumed()
        engine = eng
        viewChannel = vc
        presentation = p
    }

    private fun hide() {
        presentation?.dismiss()
        flutterView?.detachFromFlutterEngine()
        engine?.destroy()
        presentation = null
        flutterView = null
        engine = null
        viewChannel = null
    }

    override fun onDisplayAdded(displayId: Int) {
        if (enabled) show()
    }

    override fun onDisplayRemoved(displayId: Int) {
        if (presentation?.display?.displayId == displayId) hide()
    }

    override fun onDisplayChanged(displayId: Int) {}
}
