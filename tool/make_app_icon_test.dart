// Tạo ảnh nguồn cho biểu tượng ứng dụng (màn hình chính máy POS) từ assets/images/leno-logo.jpg:
//  - assets/icon/app_icon.png            logo tròn, nền trong suốt (biểu tượng thường)
//  - assets/icon/app_icon_foreground.png logo thu nhỏ vào vùng an toàn của "adaptive icon" Android
// Sau đó sinh các cỡ biểu tượng bằng flutter_launcher_icons:
//
//   flutter test tool/make_app_icon_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/images/leno-logo.jpg';
const _size = 1024.0;

void main() {
  testWidgets('make app icon sources', (tester) async {
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(File(_source).readAsBytesSync());
      final logo = (await codec.getNextFrame()).image;

      // Logo là hình tròn nằm giữa ảnh (nền trắng ở các góc): lấy hình vuông giữa ảnh,
      // cắt bớt 3% mép để bỏ viền trắng (vòng tròn trong ảnh hơi lệch tâm).
      final side = math.min(logo.width, logo.height).toDouble();
      final src = Rect.fromLTWH((logo.width - side) / 2, (logo.height - side) / 2, side, side).deflate(side * 0.03);

      Future<void> render(String path, double scale) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final d = _size * scale;
        final dst = Rect.fromCenter(center: const Offset(_size / 2, _size / 2), width: d, height: d);
        canvas.clipPath(Path()..addOval(dst));
        canvas.drawImageRect(logo, src, dst, Paint()..filterQuality = FilterQuality.high);
        final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      }

      await render('assets/icon/app_icon.png', 1.0);
      // flutter_launcher_icons tự chừa thêm 16% mỗi cạnh (inset) -> 96% x 68% ≈ 65%, nằm trong vùng an toàn ~66%.
      await render('assets/icon/app_icon_foreground.png', 0.96);
    });
  });
}
