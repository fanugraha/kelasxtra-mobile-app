import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Setiap kali AuthInterceptor mendeteksi 401, unauthorizedSignalProvider
    // berubah -> listener ini otomatis logout-kan state di UI.
    ref.listen(unauthorizedSignalProvider, (previous, next) {
      if (previous != null && next != previous) {
        state = const AuthState.unauthenticated();
      }
    });

    // Cek sesi tersimpan begitu app dibuka.
    _restoreSession();
    return const AuthState.unknown();
  }

  Future<void> _restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final hasToken = await repo.hasValidLocalToken();
    if (!hasToken) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final user = await repo.getMe();
      state = AuthState.authenticated(user);
    } on ApiException {
      // Token lokal ada tapi sudah invalid di server (mis. login di device lain)
      state = const AuthState.unauthenticated();
    }
  }

  /// Return null kalau sukses, atau pesan error kalau gagal —
  /// dipakai UI login_screen untuk menampilkan error di bawah form.
  Future<String?> login({required String email, required String password}) async {
    try {
      final user = await ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          );
      state = AuthState.authenticated(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> loginWithGoogle(String idToken) async {
    try {
      final user = await ref.read(authRepositoryProvider).loginWithGoogle(idToken);
      state = AuthState.authenticated(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Return null kalau sukses (belum login otomatis — user tetap harus
  /// verifikasi email dulu), atau pesan error kalau gagal.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? levelPendidikan,
  }) async {
    try {
      await ref.read(authRepositoryProvider).register(
            name: name,
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            phone: phone,
            levelPendidikan: levelPendidikan,
          );
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Return null kalau sukses, atau pesan error kalau gagal.
  Future<String?> forgotPassword(String email) async {
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Return null kalau sukses, atau pesan error kalau gagal.
  Future<String?> resendVerificationEmail(String email) async {
    try {
      await ref.read(authRepositoryProvider).resendVerificationEmail(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// PUT /auth/profile. Sukses -> state langsung diperbarui dengan user
  /// terbaru dari response (bukan cuma field yang diedit), supaya nama di
  /// Beranda/Akun langsung sinkron tanpa perlu refreshCurrentUser() terpisah.
  /// Return null kalau sukses, atau pesan error kalau gagal.
  Future<String?> updateProfile({
    required String name,
    String? phone,
    String? levelPendidikan,
  }) async {
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            name: name,
            phone: phone,
            levelPendidikan: levelPendidikan,
          );
      state = AuthState.authenticated(user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// PUT /auth/password.
  /// TODO: belum dicek ke server nyata apakah sukses ganti password ikut
  /// merevoke token Sanctum yang sedang dipakai request ini (beberapa
  /// setup Laravel melakukan itu). Kalau iya, request berikutnya akan
  /// 401 dan otomatis logout lewat unauthorizedSignalProvider di atas --
  /// UI ganti_password_screen.dart saat ini cuma menampilkan snackbar
  /// sukses generik, belum menangani kemungkinan itu secara eksplisit.
  /// Return null kalau sukses, atau pesan error kalau gagal.
  Future<String?> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            password: password,
            passwordConfirmation: passwordConfirmation,
          );
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> refreshCurrentUser() async {
    // Pakai maybeWhen (bukan cek tipe private _Authenticated) karena
    // konstruktor freezed bersifat library-private terhadap file ini.
    final isAuthenticated = state.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );
    if (!isAuthenticated) return;
    try {
      final user = await ref.read(authRepositoryProvider).getMe();
      state = AuthState.authenticated(user);
    } on ApiException {
      // biarkan state lama kalau gagal refresh (mis. sekadar offline)
    }
  }

  void setUser(UserModel user) => state = AuthState.authenticated(user);

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState.unauthenticated();
  }
}
