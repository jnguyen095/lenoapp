package com.leno.leno_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Máy in nhiệt cắm USB (Android USB Host): liệt kê, xin quyền, gửi lệnh ESC/POS thô.
 * Kênh "leno/usb_printer" — xem lib/printing/usb_printer.dart phía Flutter.
 */
class UsbPrinterPlugin(private val context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "leno/usb_printer"
        private const val ACTION_USB_PERMISSION = "com.leno.leno_pos.USB_PERMISSION"
        private const val CHUNK = 16 * 1024
        private const val TIMEOUT_MS = 5000
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val usb = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val pendingPermission = mutableMapOf<String, MutableList<(Boolean) -> Unit>>()

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val device: UsbDevice? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
            } else {
                @Suppress("DEPRECATION") intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
            }
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            val key = device?.deviceName ?: return
            pendingPermission.remove(key)?.forEach { it(granted || usb.hasPermission(device)) }
        }
    }

    init {
        channel.setMethodCallHandler(this)
        val filter = IntentFilter(ACTION_USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(permissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag") context.registerReceiver(permissionReceiver, filter)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        try { context.unregisterReceiver(permissionReceiver) } catch (_: IllegalArgumentException) {}
        io.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "list" -> result.success(printers().map { describe(it) })
            "requestPermission" -> {
                val device = find(call) ?: return result.error("NOT_FOUND", "Không thấy máy in USB.", null)
                ensurePermission(device) { result.success(it) }
            }
            "write" -> {
                val device = find(call) ?: return result.error(
                    "NOT_FOUND", "Không thấy máy in USB. Kiểm tra cáp USB và nguồn máy in.", null)
                val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
                ensurePermission(device) { granted ->
                    if (!granted) {
                        result.error("NO_PERMISSION", "Chưa cho phép ứng dụng dùng máy in USB này.", null)
                    } else {
                        io.execute {
                            val error = write(device, bytes)
                            main.post { if (error == null) result.success(true) else result.error("WRITE_FAILED", error, null) }
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Thiết bị có cổng ghi dạng bulk OUT — máy in (lớp 7) hoặc máy in Trung Quốc khai "vendor specific". */
    private fun printers(): List<UsbDevice> = usb.deviceList.values.filter { printerInterface(it) != null }

    private fun printerInterface(device: UsbDevice): Pair<UsbInterface, UsbEndpoint>? {
        var fallback: Pair<UsbInterface, UsbEndpoint>? = null
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            val out = (0 until intf.endpointCount).map { intf.getEndpoint(it) }.firstOrNull {
                it.type == UsbConstants.USB_ENDPOINT_XFER_BULK && it.direction == UsbConstants.USB_DIR_OUT
            } ?: continue
            if (intf.interfaceClass == UsbConstants.USB_CLASS_PRINTER) return intf to out
            if (fallback == null && intf.interfaceClass == UsbConstants.USB_CLASS_VENDOR_SPEC) fallback = intf to out
        }
        return fallback
    }

    private fun describe(d: UsbDevice): Map<String, Any?> = mapOf(
        "vendorId" to d.vendorId,
        "productId" to d.productId,
        "deviceName" to d.deviceName,
        "productName" to d.productName,
        "manufacturerName" to d.manufacturerName,
        "hasPermission" to usb.hasPermission(d),
    )

    /** Tìm theo vendorId/productId; có nhiều máy giống nhau thì ưu tiên đúng deviceName. */
    private fun find(call: MethodCall): UsbDevice? {
        val vid = call.argument<Int>("vendorId") ?: return null
        val pid = call.argument<Int>("productId") ?: return null
        val name = call.argument<String>("deviceName")
        val matches = printers().filter { it.vendorId == vid && it.productId == pid }
        return matches.firstOrNull { it.deviceName == name } ?: matches.firstOrNull()
    }

    private fun ensurePermission(device: UsbDevice, done: (Boolean) -> Unit) {
        if (usb.hasPermission(device)) return done(true)
        val waiting = pendingPermission.getOrPut(device.deviceName) { mutableListOf() }
        waiting.add(done)
        if (waiting.size > 1) return // đã đang hỏi, chờ chung kết quả

        val intent = Intent(ACTION_USB_PERMISSION).setPackage(context.packageName)
        val flags = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
        usb.requestPermission(device, PendingIntent.getBroadcast(context, 0, intent, flags))
    }

    /** Gửi dữ liệu theo từng khối; trả về thông báo lỗi hoặc null nếu thành công. */
    private fun write(device: UsbDevice, bytes: ByteArray): String? {
        val (intf, out) = printerInterface(device) ?: return "Thiết bị USB này không phải máy in."
        val conn = usb.openDevice(device) ?: return "Không mở được máy in USB (có thể ứng dụng khác đang dùng)."
        try {
            if (!conn.claimInterface(intf, true)) return "Không giữ được cổng máy in USB."
            var offset = 0
            while (offset < bytes.size) {
                val len = minOf(CHUNK, bytes.size - offset)
                val sent = conn.bulkTransfer(out, bytes, offset, len, TIMEOUT_MS)
                if (sent <= 0) return "Máy in USB không nhận dữ liệu (hết giấy, mở nắp hoặc mất kết nối?)."
                offset += sent
            }
            conn.releaseInterface(intf)
            return null
        } finally {
            conn.close()
        }
    }
}
