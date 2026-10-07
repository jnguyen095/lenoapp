import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Máy in USB đang cắm vào máy POS (Android).
class UsbPrinterDevice {
  const UsbPrinterDevice({
    required this.vendorId,
    required this.productId,
    required this.deviceName,
    this.productName,
    this.manufacturerName,
    this.hasPermission = false,
  });

  factory UsbPrinterDevice.fromMap(Map<dynamic, dynamic> m) => UsbPrinterDevice(
        vendorId: m['vendorId'] as int,
        productId: m['productId'] as int,
        deviceName: m['deviceName'] as String,
        productName: m['productName'] as String?,
        manufacturerName: m['manufacturerName'] as String?,
        hasPermission: m['hasPermission'] == true,
      );

  final int vendorId;
  final int productId;

  /// Đường dẫn Android, vd /dev/bus/usb/001/002 — đổi khi rút ra cắm lại.
  final String deviceName;
  final String? productName;
  final String? manufacturerName;
  final bool hasPermission;

  /// Mã nhận dạng dạng "0416:5011".
  String get ids => '${_hex(vendorId)}:${_hex(productId)}';

  String get label {
    final name = [manufacturerName, productName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'Máy in USB $ids' : name;
  }

  static String _hex(int v) => v.toRadixString(16).padLeft(4, '0');
}

/// Gọi phần Android (UsbPrinterPlugin.kt) qua kênh "leno/usb_printer".
class UsbPrinters {
  UsbPrinters._();

  static const channel = MethodChannel('leno/usb_printer');

  /// Chỉ dùng trong test: giả lập đang chạy trên Android.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Hiện chỉ Android có USB host cho máy in.
  static bool get supported => debugSupportedOverride ?? Platform.isAndroid;

  static Future<List<UsbPrinterDevice>> list() async {
    if (!supported) return const [];
    final raw = await channel.invokeListMethod<Map<dynamic, dynamic>>('list') ?? const [];
    return raw.map(UsbPrinterDevice.fromMap).toList(growable: false);
  }

  static Future<bool> requestPermission(int vendorId, int productId, {String? deviceName}) async {
    if (!supported) return false;
    return await channel.invokeMethod<bool>('requestPermission', {
          'vendorId': vendorId,
          'productId': productId,
          'deviceName': deviceName,
        }) ??
        false;
  }

  /// Gửi lệnh ESC/POS thô. Ném [PlatformException] (message tiếng Việt) nếu lỗi.
  static Future<void> write(int vendorId, int productId, List<int> bytes, {String? deviceName}) async {
    await channel.invokeMethod<bool>('write', {
      'vendorId': vendorId,
      'productId': productId,
      'deviceName': deviceName,
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    });
  }
}
