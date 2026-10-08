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

/// Hai cột: trái là chữ trong khung bo góc (vd "Bàn 3"), phải là các dòng chữ (vd Số HĐ, Thời gian).
/// Tỉ lệ bề rộng trái : phải = [leftFlex] : [rightFlex]; khung canh giữa theo chiều cao cột phải.
class TicketBoxSplit extends TicketLine {
  const TicketBoxSplit(this.boxText, this.lines,
      {this.note, this.leftFlex = 30, this.rightFlex = 60, this.boxScale = 1.3});

  final String boxText;
  final List<String> lines;

  /// Dòng nghiêng thêm cuối cột phải (vd "Ghi chú: Khách VIP"); null/rỗng thì bỏ.
  final String? note;
  final double leftFlex;
  final double rightFlex;
  final double boxScale;
}

/// Một hàng nhiều cột (bảng món: Tên | Đ.Giá | SL | Tiền). [flex] = tỉ lệ bề rộng từng cột,
/// [aligns] = canh lề từng cột. Ô dài tự xuống dòng trong cột của nó.
class TicketColumns extends TicketLine {
  const TicketColumns(this.cells,
      {required this.flex, required this.aligns, this.notes, this.scale = 1, this.bold = false});

  final List<String> cells;

  /// Ghi chú in nghiêng sau nội dung ô, dạng " (Ít đá)" (cùng số phần tử với [cells], null = không có).
  final List<String?>? notes;
  final List<double> flex;
  final List<TextAlign> aligns;
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

  TextPainter _painter(String text,
      {required double scale, bool bold = false, bool italic = false, TextAlign align = TextAlign.left, String? italicSuffix}) {
    TextStyle style({required bool italic}) => TextStyle(
          color: _black,
          fontFamily: fontFamily,
          fontSize: _baseSize * scale,
          height: 1.25,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        );
    return TextPainter(
      text: TextSpan(
        text: text,
        style: style(italic: italic),
        children: [
          // Ghi chú món in nghiêng ngay sau tên món.
          if ((italicSuffix ?? '').isNotEmpty) TextSpan(text: ' ($italicSuffix)', style: style(italic: true)),
        ],
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
        case TicketBoxSplit():
          const gap = 12.0, hPad = 12.0, vPad = 6.0, margin = 6.0;
          final usable = _contentWidth - gap;
          final leftW = usable * line.leftFlex / (line.leftFlex + line.rightFlex);
          final rightW = usable - leftW;
          final box = _painter(line.boxText, scale: line.boxScale, bold: true, align: TextAlign.center)
            ..layout(maxWidth: leftW - hPad * 2);
          final boxW = (box.width + hPad * 2).clamp(0.0, leftW);
          final boxH = box.height + vPad * 2;
          final right = [
            for (final t in line.lines) _painter(t, scale: 1)..layout(maxWidth: rightW),
            if ((line.note ?? '').isNotEmpty) _painter(line.note!, scale: 1, italic: true)..layout(maxWidth: rightW),
          ];
          final rightH = right.fold<double>(0, (s, p) => s + p.height);
          final h = (boxH > rightH ? boxH : rightH) + margin * 2;
          ops.add((
            h,
            (c, top) {
              // Khung tên bàn: giữa cột trái, giữa theo chiều cao.
              final boxLeft = _padding + (leftW - boxW) / 2;
              final boxTop = top + (h - boxH) / 2;
              c.drawRRect(
                RRect.fromRectAndRadius(Rect.fromLTWH(boxLeft, boxTop, boxW, boxH), const Radius.circular(12)),
                Paint()
                  ..color = _black
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.5,
              );
              box.paint(c, Offset(boxLeft + (boxW - box.width) / 2, boxTop + vPad));
              // Các dòng bên phải, cũng canh giữa theo chiều cao.
              var y = top + (h - rightH) / 2;
              for (final p in right) {
                p.paint(c, Offset(_padding + leftW + gap, y));
                y += p.height;
              }
            },
          ));
        case TicketColumns():
          const gap = 8.0;
          final totalFlex = line.flex.fold<double>(0, (s, f) => s + f);
          final usable = _contentWidth - gap * (line.cells.length - 1);
          final widths = [for (final f in line.flex) usable * f / totalFlex];
          final painters = [
            for (var i = 0; i < line.cells.length; i++)
              _painter(line.cells[i],
                  scale: line.scale, bold: line.bold, align: line.aligns[i], italicSuffix: line.notes?[i])
                ..layout(minWidth: widths[i], maxWidth: widths[i]),
          ];
          final h = painters.fold<double>(0, (m, p) => p.height > m ? p.height : m);
          ops.add((
            h,
            (c, top) {
              var x = _padding;
              for (var i = 0; i < painters.length; i++) {
                painters[i].paint(c, Offset(x, top));
                x += widths[i] + gap;
              }
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
