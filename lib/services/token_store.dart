// lib/services/token_store.dart
//
// Penyimpanan token auth mobile. Memakai flutter_secure_storage (Keystore
// Android / Keychain iOS) — lebih aman daripada shared_preferences untuk
// menyimpan kredensial sesi.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _key = 'pkm_mobile_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<String?> read() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}
