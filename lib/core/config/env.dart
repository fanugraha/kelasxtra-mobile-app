/// Konfigurasi environment aplikasi.
/// Ganti [current] ke Env.production sebelum build release.
enum Env { sandbox, production }

class AppConfig {
  AppConfig._();

  /// UBAH INI kalau mau switch environment.
  static const Env current = Env.sandbox;

  static String get apiBaseUrl {
    switch (current) {
      case Env.production:
        return 'https://api.kelasxtra.my.id/api';
      case Env.sandbox:
        // Ganti kalau backend punya domain staging terpisah.
        // Untuk sekarang sama seperti production karena OpenAPI cuma
        // mendefinisikan 1 server.
        return 'https://api.kelasxtra.my.id/api';
    }
  }

  /// Base URL Midtrans Snap WEB SDK untuk WebView checkout.
  /// Sesuai catatan di OpenAPI: snap_token dipakai lewat URL ini,
  /// BUKAN Midtrans SDK native mobile.
  static String get midtransSnapBaseUrl {
    switch (current) {
      case Env.production:
        return 'https://app.midtrans.com/snap/v2/vtweb';
      case Env.sandbox:
        return 'https://app.sandbox.midtrans.com/snap/v2/vtweb';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
