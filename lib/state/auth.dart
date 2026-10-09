import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/session_store.dart';
import '../data/pos_repository.dart';
import '../models/models.dart';

/// Máy chủ mặc định gợi ý ở màn hình đăng nhập (có thể sửa, vd http://192.168.1.10/leno).
const defaultServerUrl = 'https://leno.pickangelpark.com';

class Session {
  const Session({required this.serverUrl, required this.token, required this.user, required this.settings});

  final String serverUrl;
  final String token;
  final User user;
  final ShopSettings settings;
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// null = chưa đăng nhập. Lỗi (AsyncError) = có token nhưng không kết nối được máy chủ.
final authProvider = AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

class AuthController extends AsyncNotifier<Session?> {
  SessionStore get _store => ref.read(sessionStoreProvider);

  @override
  Future<Session?> build() async {
    final serverUrl = await _store.readServerUrl();
    final token = await _store.readToken();
    if (serverUrl == null || token == null) return null;

    try {
      return await _loadSession(serverUrl, token);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _store.clearToken();
        return null;
      }
      rethrow;
    }
  }

  Future<Session> _loadSession(String serverUrl, String token) async {
    final me = await ApiClient(serverUrl: serverUrl, token: token).get('me');
    return Session(
      serverUrl: serverUrl,
      token: token,
      user: User.fromJson(me['user'] as Map<String, dynamic>),
      settings: ShopSettings.fromJson(me['settings'] as Map<String, dynamic>),
    );
  }

  /// Ném [ApiException] nếu sai mật khẩu / không có quyền / lỗi mạng (màn hình đăng nhập tự hiện).
  Future<void> login({required String serverUrl, required String username, required String password}) async {
    final url = ApiClient.normalizeServerUrl(serverUrl);
    final res = await ApiClient(serverUrl: url).post('auth/login', {
      'username': username.trim(),
      'password': password,
      'device_name': 'Leno POS (${Platform.operatingSystem})',
    });
    final token = res['token'] as String;
    final session = await _loadSession(url, token);
    await _store.save(serverUrl: url, username: username.trim(), token: token);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    final session = state.valueOrNull;
    if (session != null) {
      try {
        await ApiClient(serverUrl: session.serverUrl, token: session.token).post('auth/logout');
      } catch (_) {
        // Không gọi được máy chủ vẫn đăng xuất trên máy này.
      }
    }
    await _store.clearToken();
    state = const AsyncData(null);
  }

  /// Máy chủ báo token hết hạn/bị thu hồi -> về màn hình đăng nhập.
  Future<void> expire() async {
    if (state.valueOrNull == null) return;
    await _store.clearToken();
    state = const AsyncData(null);
  }

  void retry() => ref.invalidateSelf();
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final session = ref.watch(authProvider).valueOrNull;
  if (session == null) throw StateError('Chưa đăng nhập');
  return ApiClient(
    serverUrl: session.serverUrl,
    token: session.token,
    onUnauthorized: () => ref.read(authProvider.notifier).expire(),
  );
});

final posRepositoryProvider = Provider<PosRepository>((ref) => PosRepository(ref.watch(apiClientProvider)));

/// Cài đặt chung của cửa hàng trên web (thông tin in phiếu, VietQR, VAT...). Lấy lúc đăng nhập,
/// tải lại khi mở lại ứng dụng / bấm "Tải lại" — không đụng tới phiên đăng nhập nên các màn hình không phải tải lại.
final shopSettingsProvider =
    NotifierProvider<ShopSettingsController, ShopSettings?>(ShopSettingsController.new);

class ShopSettingsController extends Notifier<ShopSettings?> {
  @override
  ShopSettings? build() => ref.watch(authProvider).valueOrNull?.settings;

  /// Lấy cài đặt mới nhất từ máy chủ. Lỗi mạng thì giữ cài đặt cũ và ném lỗi cho người gọi.
  Future<void> refresh() async {
    if (ref.read(authProvider).valueOrNull == null) return;
    final me = await ref.read(apiClientProvider).get('me');
    state = ShopSettings.fromJson(me['settings'] as Map<String, dynamic>);
  }
}
