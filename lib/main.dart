import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'customer_display/customer_display_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LenoApp()));
}

/// Điểm vào thứ hai: màn hình khách trên màn hình phụ của máy POS. Android chạy hàm này
/// trong một Flutter engine riêng (xem android/.../CustomerDisplayPlugin.kt).
@pragma('vm:entry-point')
void customerDisplayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CustomerDisplayApp());
}
