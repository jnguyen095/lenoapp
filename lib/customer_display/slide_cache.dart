import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'display_models.dart';

/// Lưu ảnh trình chiếu xuống máy để màn hình khách vẫn chạy khi mất mạng.
/// Tên file gồm id + dấu thời gian sửa, nên ảnh đổi trên web thì tải lại; ảnh đã xoá thì dọn file.
class SlideCache {
  SlideCache({Future<Directory> Function()? baseDir}) : _baseDir = baseDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final dir = Directory('${(await _baseDir()).path}${Platform.pathSeparator}display_slides');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String fileName(DisplaySlide s) {
    final stamp = (s.updatedAt ?? '').hashCode.toUnsigned(32).toRadixString(16);
    final dot = s.url.lastIndexOf('.');
    final ext = dot >= 0 && s.url.length - dot <= 5 ? s.url.substring(dot).toLowerCase() : '.img';
    return 'slide_${s.id}_$stamp$ext';
  }

  /// Trả về danh sách ảnh kèm đường dẫn file trên máy (ảnh tải lỗi thì file = null).
  Future<List<DisplaySlide>> sync(List<DisplaySlide> slides, Future<List<int>> Function(String url) download) async {
    final dir = await _dir();
    final keep = <String>{};
    final out = <DisplaySlide>[];

    for (final s in slides) {
      final name = fileName(s);
      keep.add(name);
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      if (!file.existsSync() || file.lengthSync() == 0) {
        try {
          final bytes = await download(s.url);
          if (bytes.isEmpty) throw const FileSystemException('empty');
          await file.writeAsBytes(bytes, flush: true);
        } catch (_) {
          out.add(s.withFile(null));
          continue;
        }
      }
      out.add(s.withFile(file.path));
    }

    // Dọn ảnh không còn dùng.
    for (final f in dir.listSync().whereType<File>()) {
      if (!keep.contains(f.uri.pathSegments.last)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
    return out;
  }
}
