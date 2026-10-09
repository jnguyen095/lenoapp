import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'display_models.dart';

/// Thông tin màn hình phụ (màn hình khách) mà Android nhận được.
class SecondaryDisplayInfo {
  const SecondaryDisplayInfo({required this.available, this.name, this.width, this.height, this.showing = false});

  factory SecondaryDisplayInfo.fromMap(Map<dynamic, dynamic> m) => SecondaryDisplayInfo(
        available: m['available'] == true,
        name: m['name'] as String?,
        width: m['width'] as int?,
        height: m['height'] as int?,
        showing: m['showing'] == true,
      );

  static const none = SecondaryDisplayInfo(available: false);

  final bool available;
  final String? name;
  final int? width;
  final int? height;

  /// Đang hiện màn hình khách trên màn hình phụ.
  final bool showing;

  String get label => available ? '${name ?? 'Màn hình phụ'} · $width×$height' : 'Không tìm thấy màn hình phụ';
}

/// Gọi phần Android (CustomerDisplayPlugin.kt): bật/tắt màn hình khách trên màn hình phụ và gửi nội dung.
/// Nền tảng khác (Windows, iOS, test) thì mọi lệnh bỏ qua.
class DisplayBridge {
  DisplayBridge();

  static const channel = MethodChannel('leno/customer_display');

  /// Chỉ dùng trong test.
  @visibleForTesting
  static bool? debugSupportedOverride;

  bool get supported => debugSupportedOverride ?? Platform.isAndroid;

  Future<SecondaryDisplayInfo> status() async {
    if (!supported) return SecondaryDisplayInfo.none;
    try {
      final m = await channel.invokeMapMethod<dynamic, dynamic>('status');
      return m == null ? SecondaryDisplayInfo.none : SecondaryDisplayInfo.fromMap(m);
    } on PlatformException {
      return SecondaryDisplayInfo.none;
    } on MissingPluginException {
      return SecondaryDisplayInfo.none;
    }
  }

  Future<void> setEnabled(bool enabled) => _call('setEnabled', enabled);

  Future<void> sendContent(DisplayContent content) => _call('content', jsonEncode(content.toJson()));

  Future<void> sendSnapshot(DisplaySnapshot snapshot) => _call('snapshot', jsonEncode(snapshot.toJson()));

  Future<void> _call(String method, Object? arg) async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>(method, arg);
    } on PlatformException catch (e) {
      debugPrint('customer display: $method failed: ${e.message}');
    } on MissingPluginException {
      // Bản build chưa có phần Android (vd chạy trên Windows) — bỏ qua.
    }
  }
}
