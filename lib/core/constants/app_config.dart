/// Konfigurasi environment aplikasi.
/// Jalankan build/run dengan --dart-define=API_BASE_URL=... untuk override,
/// contoh:
///   flutter run --dart-define=API_BASE_URL=https://api.kelasxtra.my.id/api
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.kelasxtra.my.id/api',
  );

  /// Base URL Midtrans Snap WEB SDK.
  /// PENTING (dari OpenAPI spec): snap_token dari checkout HANYA untuk
  /// Midtrans Snap WEB SDK, bukan Midtrans SDK native mobile.
  /// Buka via WebView ke: {midtransSnapBaseUrl}/{snap_token}
  static const String midtransSnapBaseUrl = String.fromEnvironment(
    'MIDTRANS_SNAP_BASE_URL',
    defaultValue: 'https://app.sandbox.midtrans.com/snap/v2/vtweb',
    // ganti ke https://app.midtrans.com/snap/v2/vtweb untuk production
  );

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
