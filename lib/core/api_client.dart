import 'package:dio/dio.dart';

/// Lỗi từ API, [message] đã là câu tiếng Việt hiển thị được cho nhân viên.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Gọi /api/v1 của máy chủ Leno. [serverUrl] là địa chỉ gốc của web,
/// ví dụ `https://leno.pickangelpark.com` hoặc `http://192.168.1.10/leno`.
class ApiClient {
  ApiClient({required String serverUrl, String? token, this.onUnauthorized})
      : serverRoot = normalizeServerUrl(serverUrl),
        _dio = Dio(BaseOptions(
          baseUrl: '${normalizeServerUrl(serverUrl)}/api/v1/',
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ));

  final Dio _dio;

  /// Địa chỉ gốc đã chuẩn hoá (không có dấu / ở cuối) — dùng để ghép đường dẫn ảnh.
  final String serverRoot;

  /// Gọi khi máy chủ trả 401 (token hết hạn / bị thu hồi).
  final void Function()? onUnauthorized;

  static String normalizeServerUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// URL đầy đủ của ảnh trả về từ API (dạng "assets/...").
  String? imageUrl(String? path) => path == null || path.isEmpty ? null : '$serverRoot/$path';

  Future<Map<String, dynamic>> get(String path) => _send(() => _dio.get<dynamic>(path));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? data]) =>
      _send(() => _dio.post<dynamic>(path, data: data ?? const <String, dynamic>{}));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> data) =>
      _send(() => _dio.patch<dynamic>(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _send(() => _dio.delete<dynamic>(path));

  /// Tải file (vd ảnh trình chiếu) theo đường dẫn tương đối trên máy chủ ("assets/...").
  Future<List<int>> downloadBytes(String path) async {
    try {
      final res = await _dio.get<List<int>>(
        imageUrl(path)!,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)),
      );
      return res.data ?? const [];
    } on DioException catch (e) {
      throw ApiException('Không tải được ảnh $path (${e.response?.statusCode ?? e.type.name}).',
          statusCode: e.response?.statusCode);
    }
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw ApiException('Phản hồi không hợp lệ từ máy chủ. Kiểm tra lại địa chỉ máy chủ.',
          statusCode: res.statusCode);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      String message;
      if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            message = 'Máy chủ phản hồi quá lâu. Vui lòng thử lại.';
          case DioExceptionType.connectionError:
            message = 'Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ máy chủ.';
          case DioExceptionType.badCertificate:
            message = 'Chứng chỉ bảo mật của máy chủ không hợp lệ.';
          default:
            message = status == 404
                ? 'Không tìm thấy API trên máy chủ này. Kiểm tra lại địa chỉ máy chủ.'
                : 'Lỗi máy chủ (${status ?? 'không rõ'}). Vui lòng thử lại.';
        }
      }

      if (status == 401) onUnauthorized?.call();
      throw ApiException(message, statusCode: status);
    }
  }
}
