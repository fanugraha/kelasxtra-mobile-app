import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';

/// Callback dipanggil saat server membalas 401 (token tidak valid/kedaluwarsa).
/// Di app, ini di-hook ke authProvider supaya user otomatis dilempar ke
/// halaman login dan token lokal dibersihkan.
///
/// Kenapa perlu ini: backend KelasXtra single-session — begitu user login
/// di device lain, token di device ini otomatis invalid di server meskipun
/// masih tersimpan di local storage.
typedef OnUnauthorized = Future<void> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.storage,
    required this.onUnauthorized,
  });

  final SecureStorageService storage;
  final OnUnauthorized onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await storage.deleteToken();
      await onUnauthorized();
    }
    handler.next(err);
  }
}
