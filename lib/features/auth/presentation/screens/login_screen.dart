import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _isResendingVerification = false;
  String? _resendFeedback;

  /// Heuristik deteksi pesan 422 "email belum diverifikasi" dari backend --
  /// lihat catatan OpenAPI di /auth/login. Backend belum punya kode error
  /// terstruktur (cuma `message` bebas), jadi deteksi berbasis substring.
  bool get _looksLikeUnverifiedEmailError {
    final msg = _errorMessage?.toLowerCase() ?? '';
    return msg.contains('verifikasi') || msg.contains('verified');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _resendFeedback = null;
    });

    final error = await ref.read(authNotifierProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });

    // Kalau sukses (error == null), redirect otomatis ditangani GoRouter
    // lewat listener ke authNotifierProvider (lihat app_router.dart).
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResendingVerification = true;
      _resendFeedback = null;
    });

    final error = await ref
        .read(authNotifierProvider.notifier)
        .resendVerificationEmail(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _isResendingVerification = false;
      _resendFeedback = error ?? 'Email verifikasi baru sudah dikirim.';
    });
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      // serverClientId WAJIB diisi (lihat AppConfig.googleServerClientId) --
      // tanpa ini idToken sering null di Android walau login Google sukses.
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleServerClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        setState(() {
          _isGoogleLoading = false;
          // Kalau pesan ini masih muncul setelah serverClientId diisi
          // dengan benar, kemungkinan besar client ID yang dipasang salah
          // tipe (harus "Web application", bukan Android/iOS) -- lihat
          // catatan di AppConfig.googleServerClientId.
          _errorMessage = 'Gagal mengambil token dari Google. Coba lagi.';
        });
        return;
      }

      final error = await ref
          .read(authNotifierProvider.notifier)
          .loginWithGoogle(idToken);

      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = error;
      });

      // Kalau sukses, redirect otomatis ditangani GoRouter lewat
      // listener ke authNotifierProvider — sama seperti alur _submit().
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = 'Tidak bisa terhubung ke Google. Periksa koneksi kamu.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.brand500,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'K',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Masuk ke KelasXtra',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lanjutkan persiapan CPNS-mu hari ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.neutral500, fontSize: 14),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger600, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppColors.danger700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        if (_looksLikeUnverifiedEmailError) ...[
                          const SizedBox(height: 10),
                          if (_resendFeedback != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                _resendFeedback!,
                                style: const TextStyle(color: AppColors.danger700, fontSize: 12),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _isResendingVerification ? null : _resendVerification,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: _isResendingVerification
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Kirim ulang email verifikasi',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(Icons.mail_outline, color: AppColors.neutral400),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neutral400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.neutral400,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Lupa password?'),
                  ),
                ),
                const SizedBox(height: 8),

                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Masuk'),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.neutral200)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau', style: TextStyle(color: AppColors.neutral400, fontSize: 12)),
                    ),
                    const Expanded(child: Divider(color: AppColors.neutral200)),
                  ],
                ),
                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Image.asset('assets/icons/google_logo.png', height: 20),
                  label: Text(_isGoogleLoading ? 'Menghubungkan...' : 'Masuk dengan Google'),
                ),
                const SizedBox(height: 28),

                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun?',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text('Daftar sekarang'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
