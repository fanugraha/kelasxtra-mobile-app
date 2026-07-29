/// Konfigurasi environment aplikasi — SATU-SATUNYA AppConfig di project ini.
/// (Sempat ada duplikat di core/constants/app_config.dart, sudah dihapus —
/// itu dead code yang tidak pernah diimport, dan nilainya beda/tidak sinkron
/// dengan yang di sini. Jangan buat AppConfig baru di file lain lagi.)
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

  /// OAuth Client ID bertipe "Web application" dari Google Cloud Console
  /// (BUKAN client ID Android/iOS). Wajib diisi supaya GoogleSignIn bisa
  /// mengembalikan idToken (JWT) di Android.
  static const String googleServerClientId =
    '554654745094-lngi0uggo8manch1ob065omv1q50c975.apps.googleusercontent.com';
}
