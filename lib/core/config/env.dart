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

  /// OAuth Client ID bertipe "Web application" dari Google Cloud Console
  /// (BUKAN client ID Android/iOS). Wajib diisi supaya `GoogleSignIn`
  /// bisa mengembalikan `idToken` (JWT) di Android -- tanpa ini,
  /// `account.authentication.idToken` sering balik `null` di device
  /// Android asli meski login Google sukses secara visual, sehingga
  /// POST /auth/google akan selalu gagal dengan pesan
  /// "Gagal mengambil token dari Google. Coba lagi."
  ///
  /// Ambil dari: Google Cloud Console > APIs & Services > Credentials >
  /// OAuth 2.0 Client IDs > (client dengan Application type = Web
  /// application). Biasanya ini client ID yang SAMA dengan yang dipakai
  /// backend Laravel untuk verifikasi token di endpoint /auth/google
  /// (Google\Client::setClientId()).
  ///
  /// TODO(programmer): isi nilai asli di bawah ini sebelum build ke
  /// Android. Di iOS biasanya tetap jalan tanpa ini (pakai REVERSED_CLIENT_ID
  /// dari GoogleService-Info.plist), tapi tetap disarankan diisi supaya
  /// perilaku 2 platform konsisten.
  static const String googleServerClientId =
    '554654745094-lngi0uggo8manch1ob065omv1q50c975.apps.googleusercontent.com';
}
