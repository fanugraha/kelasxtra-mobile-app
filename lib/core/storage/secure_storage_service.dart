import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_service.g.dart';

/// Wrapper flutter_secure_storage khusus untuk auth token Sanctum.
///
/// PENTING (lihat catatan OpenAPI): login baru di backend akan menghapus
/// SEMUA token lama milik user (single-session). Jadi kalau app di-logout
/// paksa dengan response 401, token lokal WAJIB dihapus juga.
class SecureStorageService {
  SecureStorageService(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'kelasxtra_auth_token';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  Future<bool> hasToken() async => (await readToken()) != null;
}

@Riverpod(keepAlive: true)
SecureStorageService secureStorageService(SecureStorageServiceRef ref) {
  return SecureStorageService(const FlutterSecureStorage());
}
