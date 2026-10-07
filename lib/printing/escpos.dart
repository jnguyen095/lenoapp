import 'dart:math' as math;
import 'dart:typed_data';

/// Lệnh ESC/POS tối thiểu cho máy in nhiệt: khởi tạo, in ảnh raster, đẩy giấy, cắt.
/// In dạng ảnh để tiếng Việt luôn đúng dấu (không phụ thuộc bảng mã của máy in).
class EscPos {
  EscPos._();

  static const initialize = [0x1B, 0x40]; // ESC @
  static const cutPartial = [0x1D, 0x56, 0x42, 0x00]; // GS V 66 0 — đẩy giấy tới dao rồi cắt

  static List<int> feedLines(int n) => [0x1B, 0x64, n.clamp(0, 255)]; // ESC d n

  /// Ảnh RGBA (width × height) -> lệnh GS v 0, chia khối [chunkRows] dòng cho máy in bộ đệm nhỏ.
  /// Điểm tối hơn [threshold] (độ sáng 0..255) in thành chấm đen.
  static Uint8List raster(Uint8List rgba, int width, int height, {int threshold = 160, int chunkRows = 128}) {
    final bytesPerRow = (width + 7) ~/ 8;
    final out = BytesBuilder(copy: false);

    for (var y0 = 0; y0 < height; y0 += chunkRows) {
      final rows = math.min(chunkRows, height - y0);
      out.add([
        0x1D, 0x76, 0x30, 0x00, // GS v 0, chế độ bình thường
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        rows & 0xFF, (rows >> 8) & 0xFF,
      ]);

      final block = Uint8List(bytesPerRow * rows);
      for (var y = 0; y < rows; y++) {
        final rowStart = (y0 + y) * width * 4;
        for (var x = 0; x < width; x++) {
          final i = rowStart + x * 4;
          final alpha = rgba[i + 3];
          if (alpha < 128) continue; // trong suốt = giấy trắng
          final luminance = (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
          if (luminance < threshold) {
            block[y * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
          }
        }
      }
      out.add(block);
    }
    return out.toBytes();
  }

  /// Một lần in hoàn chỉnh: khởi tạo, ảnh, đẩy giấy, cắt — lặp [copies] lần.
  static Uint8List job(Uint8List rasterBytes, {int copies = 1, bool cut = true}) {
    final out = BytesBuilder(copy: false);
    for (var c = 0; c < copies; c++) {
      out.add(initialize);
      out.add(rasterBytes);
      out.add(feedLines(4));
      if (cut) out.add(cutPartial);
    }
    return out.toBytes();
  }
}
