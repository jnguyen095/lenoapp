package com.leno.leno_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var usbPrinter: UsbPrinterPlugin? = null
    private var customerDisplay: CustomerDisplayPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbPrinter = UsbPrinterPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // Màn hình khách cần Activity (Presentation gắn với cửa sổ của Activity).
        customerDisplay = CustomerDisplayPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usbPrinter?.dispose()
        usbPrinter = null
        customerDisplay?.dispose()
        customerDisplay = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
