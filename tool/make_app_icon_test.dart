// Tạo ảnh nguồn cho biểu tượng ứng dụng (màn hình chính máy POS) từ assets/images/nang-nghieng-app-icon.png
// (favicon 512px của web: chữ "n" vàng trên nền xanh bo góc):
//  - assets/icon/app_icon.png            biểu tượng đầy đủ (biểu tượng thường, iOS)
//  - assets/icon/app_icon_foreground.png thu nhỏ vào vùng an toàn của "adaptive icon" Android; nền adaptive icon
//    là màu xanh của biểu tượng (in ra khi chạy — đặt vào adaptive_icon_background trong pubspec.yaml)
// Sau đó sinh các cỡ biểu tượng bằng flutter_launcher_icons:
//
//   flutter test tool/make_app_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/images/nang-nghieng-app-icon.png';
const _size = 1024.0;

void main() {
  testWidgets('make app icon sources', (tester) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File(_source).readAsBytesSync());
      final icon = (await codec.getNextFrame()).image;

      // Màu nền xanh: điểm giữa mép trên (trong hình vuông bo góc, ngoài chữ "n").
      final pixels = (await icon.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final i = ((icon.height * 0.06).round() * icon.width + icon.width ~/ 2) * 4;
      final hex = [pixels.getUint8(i), pixels.getUint8(i + 1), pixels.getUint8(i + 2)]
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join()
          .toUpperCase();
      // ignore: avoid_print
      print('background #$hex');

      final src = Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble());
      Future<void> render(String path, double scale) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final d = _size * scale;
        final dst = Rect.fromCenter(center: const Offset(_size / 2, _size / 2), width: d, height: d);
        canvas.drawImageRect(icon, src, dst, Paint()..filterQuality = FilterQuality.high);
        final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      }

      await render('assets/icon/app_icon.png', 1.0);
      // flutter_launcher_icons tự chừa thêm 16% mỗi cạnh (inset) -> 96% x 68% ≈ 65%, nằm trong vùng an toàn ~66%.
      // Góc bo trong suốt của ảnh lộ ra nền adaptive (cùng màu xanh) nên trông liền một khối.
      await render('assets/icon/app_icon_foreground.png', 0.96);
    });
  });
}
