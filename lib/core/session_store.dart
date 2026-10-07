import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu địa chỉ máy chủ (SharedPreferences) và token đăng nhập (Keychain/Keystore).
class SessionStore {
  static const _serverUrlKey = 'server_url';
  static const _usernameKey = 'last_username';
  static const _tokenKey = 'api_token';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readServerUrl() async => (await SharedPreferences.getInstance()).getString(_serverUrlKey);

  Future<String?> readLastUsername() async => (await SharedPreferences.getInstance()).getString(_usernameKey);

  Future<String?> readToken() => _secure.read(key: _tokenKey);

  Future<void> save({required String serverUrl, required String username, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl);
    await prefs.setString(_usernameKey, username);
    await _secure.write(key: _tokenKey, value: token);
  }

  Future<void> clearToken() => _secure.delete(key: _tokenKey);
}
