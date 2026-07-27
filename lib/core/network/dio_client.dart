import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

part 'dio_client.g.dart';

/// Provider Dio instance tunggal untuk seluruh app.
/// `onUnauthorized` di-wire ke authProvider lewat listener di main.dart
/// atau langsung di authProvider (lihat features/auth/presentation/providers).
@Riverpod(keepAlive: true)
Dio dio(DioRef ref) {
  final storage = ref.watch(secureStorageServiceProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: 'application/json',
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storage: storage,
      onUnauthorized: () async {
        // Diisi ulang (override) oleh authProvider saat inisialisasi,
        // supaya dio_client tidak perlu tahu soal AuthNotifier langsung
        // (hindari circular dependency antar provider).
        ref.read(unauthorizedSignalProvider.notifier).notifyUnauthorized();
      },
    ),
  );

  // Logger hanya aktif saat debug — aman untuk production karena
  // tidak akan mencetak apapun kalau di-strip lewat --dart-define nanti.
  assert(() {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        compact: true,
      ),
    );
    return true;
  }());

  return dio;
}

/// Signal sederhana yang di-listen oleh AuthNotifier untuk tahu kapan
/// harus force-logout akibat 401 dari interceptor, tanpa Dio perlu
/// import langsung provider Auth (mencegah circular import).
@Riverpod(keepAlive: true)
class UnauthorizedSignal extends _$UnauthorizedSignal {
  @override
  int build() => 0;

  void notifyUnauthorized() => state++;
}
