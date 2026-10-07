package com.leno.leno_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var usbPrinter: UsbPrinterPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usbPrinter = UsbPrinterPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        usbPrinter?.dispose()
        usbPrinter = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
