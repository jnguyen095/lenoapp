import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'customer_display_view.dart';
import 'display_models.dart';

/// Ứng dụng chạy trên màn hình phụ (màn hình khách) — một Flutter engine riêng do Android tạo
/// (CustomerDisplayPlugin.kt, điểm vào `customerDisplayMain` trong main.dart).
/// Chỉ nhận nội dung từ ứng dụng chính qua kênh 'leno/customer_display/view' rồi vẽ.
class CustomerDisplayApp extends StatefulWidget {
  const CustomerDisplayApp({super.key});

  static const channel = MethodChannel('leno/customer_display/view');

  @override
  State<CustomerDisplayApp> createState() => _CustomerDisplayAppState();
}

class _CustomerDisplayAppState extends State<CustomerDisplayApp> {
  DisplayContent _content = const DisplayContent();
  DisplaySnapshot _snapshot = const DisplaySnapshot.idle();

  @override
  void initState() {
    super.initState();
    CustomerDisplayApp.channel.setMethodCallHandler(_onMessage);
    // Báo đã sẵn sàng -> phía Android gửi lại nội dung + trạng thái mới nhất.
    CustomerDisplayApp.channel.invokeMethod<void>('ready');
  }

  Future<void> _onMessage(MethodCall call) async {
    final data = call.arguments is String ? jsonDecode(call.arguments as String) as Map<String, dynamic> : null;
    if (data == null) return;
    setState(() {
      if (call.method == 'content') _content = DisplayContent.fromJson(data);
      if (call.method == 'snapshot') _snapshot = DisplaySnapshot.fromJson(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0190DB)),
      home: Scaffold(body: CustomerDisplayView(content: _content, snapshot: _snapshot)),
    );
  }
}
