import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Nội dung một phiếu in, dựng từ các dòng đơn giản rồi vẽ thành ảnh đúng khổ giấy.
sealed class TicketLine {
  const TicketLine();
}

class TicketText extends TicketLine {
  const TicketText(this.text, {this.align = TextAlign.left, this.scale = 1, this.bold = false, this.italic = false});

  final String text;
  final TextAlign align;
  final double scale;
  final bool bold;
  final bool italic;
}

/// Hai cột: trái (tự xuống dòng) và phải (vd tên + thành tiền).
class TicketRow extends TicketLine {
  const TicketRow(this.left, this.right, {this.scale = 1, this.bold = false});

  final String left;
  final String right;
  final double scale;
  final bool bold;
}

class TicketDivider extends TicketLine {
  const TicketDivider();
}

class TicketSpace extends TicketLine {
  const TicketSpace([this.lines = 0.5]);

  final double lines;
}

class Ticket {
  const Ticket(this.lines);

  final List<TicketLine> lines;
}

/// Vẽ phiếu thành ảnh rộng [widthDots] điểm (576 = giấy 80 mm, 384 = 58 mm).
class TicketRenderer {
  TicketRenderer({required this.widthDots, this.fontFamily = 'Roboto'});

  final int widthDots;
  final String fontFamily;

  double get _baseSize => widthDots >= 512 ? 24 : 19;
  double get _padding => widthDots >= 512 ? 10 : 6;
  double get _contentWidth => widthDots - _padding * 2;

  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);

  TextPainter _painter(String text, {required double scale, bool bold = false, bool italic = false, TextAlign align = TextAlign.left}) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: _black,
          fontFamily: fontFamily,
          fontSize: _baseSize * scale,
          height: 1.25,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
  }

  /// Ảnh phiếu (nền trắng, chữ đen).
  Future<ui.Image> renderImage(Ticket ticket) {
    final ops = <(double, void Function(Canvas canvas, double top))>[];

    for (final line in ticket.lines) {
      switch (line) {
        case TicketText():
          final p = _painter(line.text, scale: line.scale, bold: line.bold, italic: line.italic, align: line.align)
            ..layout(minWidth: _contentWidth, maxWidth: _contentWidth);
          ops.add((p.height, (c, top) => p.paint(c, Offset(_padding, top))));
        case TicketRow():
          final right = _painter(line.right, scale: line.scale, bold: line.bold)..layout(maxWidth: _contentWidth);
          final left = _painter(line.left, scale: line.scale, bold: line.bold)
            ..layout(maxWidth: (_contentWidth - right.width - 12).clamp(40, _contentWidth));
          final h = left.height > right.height ? left.height : right.height;
          ops.add((
            h,
            (c, top) {
              left.paint(c, Offset(_padding, top));
              // Số tiền canh theo dòng cuối của tên món.
              right.paint(c, Offset(widthDots - _padding - right.width, top + h - right.height));
            },
          ));
        case TicketDivider():
          final h = _baseSize * 0.9;
          ops.add((
            h,
            (c, top) {
              final paint = Paint()
                ..color = _black
                ..strokeWidth = 2;
              final y = top + h / 2;
              for (var x = _padding; x < widthDots - _padding; x += 12) {
                c.drawLine(Offset(x, y), Offset(x + 7, y), paint);
              }
            },
          ));
        case TicketSpace():
          ops.add((_baseSize * 1.25 * line.lines, (_, _) {}));
      }
    }

    final height = (ops.fold<double>(0, (sum, op) => sum + op.$1) + _padding * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, widthDots.toDouble(), height.toDouble()), Paint()..color = _white);

    var top = _padding;
    for (final (h, paint) in ops) {
      paint(canvas, top);
      top += h;
    }
    return recorder.endRecording().toImage(widthDots, height);
  }

  /// Ảnh phiếu dạng RGBA thô (để chuyển sang lệnh ESC/POS).
  Future<({Uint8List rgba, int width, int height})> renderRgba(Ticket ticket) async {
    final image = await renderImage(ticket);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (rgba: data!.buffer.asUint8List(), width: image.width, height: image.height);
    } finally {
      image.dispose();
    }
  }
}
