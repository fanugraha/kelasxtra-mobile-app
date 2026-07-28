import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../auth_api_service.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final AuthApiService _api;
  final SecureStorageService _storage;

  Future<String> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? levelPendidikan,
  }) async {
    try {
      final res = await _api.register({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null) 'phone': phone,
        if (levelPendidikan != null) 'level_pendidikan': levelPendidikan,
      });
      return (res.response.data?['message'] as String?) ??
          'Registrasi berhasil. Silakan cek email Anda.';
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserModel> login({required String email, required String password}) async {
    try {
      final AuthResponseModel res = await _api.login({
        'email': email,
        'password': password,
      });
      await _storage.saveToken(res.token);
      return res.user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// [idToken] wajib Google ID Token (JWT) dari google_sign_in package,
  /// BUKAN access token OAuth biasa — lihat catatan di OpenAPI.
  Future<UserModel> loginWithGoogle(String idToken) async {
    try {
      final res = await _api.loginWithGoogle({'credential': idToken});
      await _storage.saveToken(res.token);
      return res.user;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> resendVerificationEmail(String email) async {
    try {
      await _api.resendVerificationEmail({'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _api.forgotPassword({'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// CATATAN: belum dipanggil dari AuthNotifier/screen manapun -- SENGAJA.
  /// Link reset password di email mengarah ke web app (yang sudah handle
  /// flow-nya), bukan ke native app ini. Method ini disiapkan kalau nanti
  /// ada keputusan produk untuk reset password langsung di app (perlu
  /// deep link + screen input password baru); sampai saat itu, biarkan
  /// tidak terpakai daripada dihapus.
  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _api.resetPassword({
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserModel> getMe() async {
    try {
      return await _api.getMe();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserModel> updateProfile({
    required String name,
    String? phone,
    String? levelPendidikan,
  }) async {
    try {
      return await _api.updateProfile({
        'name': name,
        if (phone != null) 'phone': phone,
        if (levelPendidikan != null) 'level_pendidikan': levelPendidikan,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await _api.changePassword({
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Logout ke server (hapus token device ini) lalu selalu hapus token
  /// lokal, apapun hasilnya — supaya user tidak pernah "nyangkut" login
  /// di UI walau request logout gagal karena jaringan.
  Future<void> logout() async {
    try {
      await _api.logout();
    } on DioException catch (_) {
      // sengaja diabaikan — lanjut hapus token lokal
    } finally {
      await _storage.deleteToken();
    }
  }

  Future<bool> hasValidLocalToken() => _storage.hasToken();
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(
    ref.watch(authApiServiceProvider),
    ref.watch(secureStorageServiceProvider),
  );
}
