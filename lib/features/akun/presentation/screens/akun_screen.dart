// lib/features/akun/presentation/screens/akun_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../beranda/presentation/providers/beranda_provider.dart';

class AkunScreen extends ConsumerWidget {
  const AkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

    // Fallback jaga-jaga -- AppShell (lewat redirect di app_router.dart)
    // seharusnya cuma bisa dicapai kalau authState = authenticated, tapi
    // ini menghindari null-check crash kalau state berubah tepat di frame
    // yang sama (mis. race dengan logout / token expired).
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 20),
            if (user.emailVerifiedAt == null) ...[
              const _EmailNotVerifiedBanner(),
              const SizedBox(height: 20),
            ],
            const _SubscriptionCard(),
            const SizedBox(height: 20),
            _MenuSection(
              children: [
                _MenuTile(
                  icon: Icons.person_outline,
                  label: 'Edit Profil',
                  onTap: () => context.push('/akun/edit-profil'),
                ),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Ganti Password',
                  onTap: () => context.push('/akun/ganti-password'),
                ),
                // TODO: menu "Ganti Password" di atas seharusnya disembunyikan
                // atau di-disable kalau user login via Google (googleId !=
                // null) -- akun Google tidak punya current_password untuk
                // divalidasi PUT /auth/password. Belum ada percabangan UI
                // untuk ini karena belum ada akun tes Google buat verifikasi
                // response error yang sebenarnya dari backend (422? pesan
                // apa?) -- cek dulu sebelum menambahkan penanganannya.
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.danger600),
                label: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk mengakses akun ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.brand500,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailNotVerifiedBanner extends ConsumerStatefulWidget {
  const _EmailNotVerifiedBanner();

  @override
  ConsumerState<_EmailNotVerifiedBanner> createState() => _EmailNotVerifiedBannerState();
}

class _EmailNotVerifiedBannerState extends ConsumerState<_EmailNotVerifiedBanner> {
  bool _isSending = false;
  bool _sent = false;

  Future<void> _resend(String email) async {
    setState(() => _isSending = true);
    final error = await ref.read(authNotifierProvider.notifier).resendVerificationEmail(email);
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = error == null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (u) => u.email,
          orElse: () => '',
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold500.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.gold600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email belum diverifikasi',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _sent
                      ? 'Link verifikasi baru sudah dikirim ke $email.'
                      : 'Beberapa fitur mungkin terbatas sampai email diverifikasi.',
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 12),
                ),
                if (!_sent) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isSending ? null : () => _resend(email),
                    child: Text(
                      _isSending ? 'Mengirim...' : 'Kirim ulang email verifikasi',
                      style: const TextStyle(
                        color: AppColors.brand500,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TODO: kartu ini SENGAJA numpang data dari berandaNotifierProvider (yang
/// sudah menggabungkan GET /my-subscription untuk kartu Beranda) supaya
/// tidak ada 2 panggilan API terpisah untuk data yang sama. Begitu ada
/// keputusan produk soal fitur Subscription penuh (riwayat langganan,
/// upgrade/renew, pilih program) -- lib/features/subscription/ saat ini
/// masih kosong -- pindahkan ke provider/repository Subscription sendiri
/// dan lepas dependency silang ke Beranda ini.
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return berandaAsync.when(
      data: (data) {
        final isActive = data.hasActiveSubscription;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? AppColors.success50 : AppColors.neutral100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.verified_outlined : Icons.info_outline,
                color: isActive ? AppColors.success600 : AppColors.neutral500,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'Langganan Aktif' : 'Belum Berlangganan',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.neutral900),
                    ),
                    if (isActive && data.subscriptionPackageName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        data.subscriptionPackageName!,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // Gagal-lembut: kalau data Beranda gagal load (mis. offline), kartu
      // status langganan cukup disembunyikan -- bukan alasan mengganggu
      // seluruh halaman Akun yang isinya hal lain juga (profil, menu, dst).
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, color: AppColors.neutral200),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neutral600, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.neutral900)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 20),
      onTap: onTap,
    );
  }
}
