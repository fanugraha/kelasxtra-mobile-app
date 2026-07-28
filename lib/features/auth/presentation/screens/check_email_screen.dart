import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layar 4 — "Cek email kamu", ditampilkan setelah /auth/register sukses.
/// User belum bisa login sampai link verifikasi di email diklik.
///
/// CATATAN INTEGRASI: mengasumsikan authNotifierProvider.notifier punya
/// method `resendVerificationEmail({required String email})` yang
/// mem-POST ke /email/verification-notification dan return String? error
/// (endpoint ini selalu 200 di backend, jadi error di sini realistanya
/// hanya untuk kegagalan jaringan).
class CheckEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const CheckEmailScreen({super.key, required this.email});

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  static const _cooldownSeconds = 60;

  Timer? _timer;
  int _secondsLeft = 0;
  bool _isResending = false;
  String? _feedback;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _feedback = null;
    });

    final error = await ref
        .read(authNotifierProvider.notifier)
        .resendVerificationEmail(widget.email);

    if (!mounted) return;
    setState(() {
      _isResending = false;
      _feedback = error ?? 'Email verifikasi baru sudah dikirim.';
    });

    if (error == null) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && !_isResending;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.brand500.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    size: 40, color: AppColors.brand500),
              ),
              const SizedBox(height: 24),
              Text(
                'Cek email kamu',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutral900,
                    ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 13, height: 1.5),
                  children: [
                    const TextSpan(text: 'Kami sudah kirim link verifikasi ke\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Klik link di email tersebut untuk mengaktifkan akun.',
                style: TextStyle(color: AppColors.neutral500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (_feedback != null) ...[
                Text(
                  _feedback!,
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: canResend ? _resend : null,
                  child: _isResending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _secondsLeft > 0
                              ? 'Kirim ulang (${_secondsLeft}s)'
                              : 'Kirim Ulang Email',
                        ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Balik ke step 1 form (nama+email) untuk ganti email.
                  context.pop();
                },
                child: const Text('Salah email? Ganti di sini'),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Sudah verifikasi? Masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}