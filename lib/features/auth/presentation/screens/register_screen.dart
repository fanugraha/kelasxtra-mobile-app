import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layar 1 — Pilihan Masuk.
///
/// Redesign v3: "big brand" onboarding — brand mark jadi anchor visual
/// utama (bukan sekadar ikon kecil di pojok), dengan wordmark di
/// bawahnya supaya identitas Kelasxtra langsung terasa begitu layar
/// dibuka — pola yang dipakai Gojek/Tiket.com/Traveloka di layar
/// pertama onboarding mereka. Sisanya tetap restrained: satu warna
/// aksen, tipografi jelas, whitespace lega, tanpa ornamen dekoratif
/// yang tidak fungsional.
///
/// Google sign-in ditonjolkan sebagai jalur utama (instan, tanpa verifikasi
/// email — lihat AuthController::loginWithGoogle di backend). Daftar manual
/// jadi fallback yang membawa user ke wizard 2 step (RegisterFormScreen).
///
/// CATATAN INTEGRASI: layar ini mengasumsikan authNotifierProvider.notifier
/// punya method `loginWithGoogle({required String credential})` yang
/// mem-POST ke /auth/google dan me-return String? error (null = sukses).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  bool _isGoogleLoading = false;
  String? _errorMessage;

  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _stats = [
    (icon: Icons.edit_note_outlined, label: 'Latihan Soal'),
    (icon: Icons.emoji_events_outlined, label: 'Try Out'),
    (icon: Icons.insights_outlined, label: 'Analisis Nilai'),
  ];

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.of(context).disableAnimations) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
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

      if (error == null) {
        context.go('/home');
      }
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppColors.neutral700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),

                        Text(
                          'Siap lolos seleksi CPNS?',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral900,
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Buat akun untuk mulai latihan soal & try out.',
                          style: TextStyle(
                            color: AppColors.neutral500,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // --- Strip nilai jual, dengan ikon berbingkai lembut ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final stat in _stats)
                              Expanded(child: _StatChip(stat: stat)),
                          ],
                        ),
                        const SizedBox(height: 32),

                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: 16),
                        ],

                        // ---- Jalur utama: Google ----
                        SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.neutral200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isGoogleLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Image.asset('assets/icons/google_logo.png', height: 20),
                            label: Text(
                              _isGoogleLoading ? 'Menghubungkan...' : 'Lanjutkan dengan Google',
                              style: const TextStyle(
                                color: AppColors.neutral900,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppColors.neutral200)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                'atau',
                                style: TextStyle(color: AppColors.neutral400, fontSize: 12),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.neutral200)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ---- Fallback: daftar manual via email ----
                        SizedBox(
                          height: 54,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brand500.withOpacity(0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton(
                              onPressed: () => context.push('/register/form'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand500,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Daftar dengan Email',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Sudah punya akun?',
                              style: TextStyle(color: AppColors.neutral600, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () => context.pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brand600,
                              ),
                              child: const Text(
                                'Masuk',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu item nilai jual dalam strip — ikon dibungkus lingkaran lembut
/// bertone brand, meniru pola "feature highlight" onboarding brand besar.
class _StatChip extends StatelessWidget {
  final ({IconData icon, String label}) stat;
  const _StatChip({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brand500.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(stat.icon, size: 20, color: AppColors.brand600),
        ),
        const SizedBox(height: 8),
        Text(
          stat.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.neutral600,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}