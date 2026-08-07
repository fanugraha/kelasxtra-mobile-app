mkdir -p lib/features/privasi/data/repositories lib/features/privasi/presentation/screens

cat > lib/features/privasi/data/privasi_api_service.dart << 'EOF_API'
// lib/features/privasi/data/privasi_api_service.dart
//
// Panggilan HTTP mentah untuk Privasi. 1 endpoint sederhana, tidak perlu
// Retrofit -- ikuti pola raw Dio modul-modul lain.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

part 'privasi_api_service.g.dart';

class PrivasiApiService {
  PrivasiApiService(this._dio);

  final Dio _dio;

  /// PATCH /user/privacy -- response cuma {"message": "..."}, TIDAK
  /// mengembalikan user terbaru. Caller (repository/provider) yang
  /// bertanggung jawab update local UserModel kalau sukses.
  Future<void> updatePrivacy({required bool hideFromLeaderboardFeed}) async {
    await _dio.patch(
      ApiEndpoints.userPrivacy,
      data: {'hide_from_leaderboard_feed': hideFromLeaderboardFeed},
    );
  }
}

@Riverpod(keepAlive: true)
PrivasiApiService privasiApiService(PrivasiApiServiceRef ref) {
  return PrivasiApiService(ref.watch(dioProvider));
}
EOF_API

cat > lib/features/privasi/data/repositories/privasi_repository.dart << 'EOF_REPO'
// lib/features/privasi/data/repositories/privasi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../privasi_api_service.dart';

part 'privasi_repository.g.dart';

class PrivasiRepository {
  PrivasiRepository(this._api);

  final PrivasiApiService _api;

  Future<void> updatePrivacy({required bool hideFromLeaderboardFeed}) async {
    try {
      await _api.updatePrivacy(hideFromLeaderboardFeed: hideFromLeaderboardFeed);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
PrivasiRepository privasiRepository(PrivasiRepositoryRef ref) {
  return PrivasiRepository(ref.watch(privasiApiServiceProvider));
}
EOF_REPO

cat > lib/features/privasi/presentation/screens/privasi_screen.dart << 'EOF_SCREEN'
// lib/features/privasi/presentation/screens/privasi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/privasi_repository.dart';

class PrivasiScreen extends ConsumerWidget {
  const PrivasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Privasi'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _HideFromLeaderboardTile(initialValue: user.hideFromLeaderboardFeed),
                ],
              ),
            ),
    );
  }
}

class _HideFromLeaderboardTile extends ConsumerStatefulWidget {
  const _HideFromLeaderboardTile({required this.initialValue});
  final bool initialValue;

  @override
  ConsumerState<_HideFromLeaderboardTile> createState() => _HideFromLeaderboardTileState();
}

class _HideFromLeaderboardTileState extends ConsumerState<_HideFromLeaderboardTile> {
  late bool _value = widget.initialValue;
  bool _isSaving = false;

  Future<void> _handleChanged(bool newValue) async {
    final previous = _value;
    // Optimistic update -- toggle terasa instan, di-revert kalau ternyata
    // gagal simpan ke server.
    setState(() {
      _value = newValue;
      _isSaving = true;
    });

    try {
      await ref.read(privasiRepositoryProvider).updatePrivacy(hideFromLeaderboardFeed: newValue);
      // PATCH /user/privacy cuma balikin {"message": ...}, bukan user
      // terbaru -- update UserModel lokal manual lewat setUser() supaya
      // authNotifierProvider (dipakai di mana-mana, termasuk kalau screen
      // ini dibuka lagi) langsung sinkron tanpa perlu refreshCurrentUser()
      // (network call tambahan yang tidak perlu untuk 1 field ini).
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );
      if (currentUser != null) {
        authNotifier.setUser(currentUser.copyWith(hideFromLeaderboardFeed: newValue));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _value = previous;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _value,
        onChanged: _isSaving ? null : _handleChanged,
        activeColor: AppColors.brand500,
        title: const Text(
          'Sembunyikan dari Feed Peringkat',
          style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Nama dan skormu tidak akan muncul di papan peringkat latihan soal mingguan '
          'kalau ini diaktifkan. Kamu tetap bisa mengerjakan latihan seperti biasa.',
          style: TextStyle(color: AppColors.neutral500, fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}
EOF_SCREEN

cat > lib/features/akun/presentation/screens/akun_screen.dart << 'EOF_AKUN'
// lib/features/akun/presentation/screens/akun_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

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
                  icon: Icons.inventory_2_outlined,
                  label: 'Paket Saya',
                  onTap: () => context.push('/paket-saya'),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat Transaksi',
                  onTap: () => context.push('/transaksi'),
                ),
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
                _MenuTile(
                  icon: Icons.shield_outlined,
                  label: 'Privasi',
                  onTap: () => context.push('/privasi'),
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

/// Sebelumnya kartu ini numpang data dari berandaNotifierProvider (satu-
/// satunya konsumen GET /my-subscription waktu itu). Sekarang lib/features/
/// subscription/ sudah ada provider sendiri (mySubscriptionNotifierProvider),
/// jadi dependency silang ke Beranda dilepas -- kartu ini juga jadi entry
/// point ke layar Langganan (daftar plan + detail).
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(mySubscriptionNotifierProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/langganan'),
      child: subAsync.when(
        data: (subscription) {
          final isActive = subscription != null;
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
                      if (isActive) ...[
                        const SizedBox(height: 2),
                        Text(
                          subscription.plan.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        // Gagal-lembut: kalau /my-subscription gagal load (mis. offline), kartu
        // status langganan cukup disembunyikan -- bukan alasan mengganggu
        // seluruh halaman Akun yang isinya hal lain juga (profil, menu, dst).
        error: (_, __) => const SizedBox.shrink(),
      ),
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
EOF_AKUN

cat > lib/core/router/app_router.dart << 'EOF_ROUTER'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_form_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/akun/presentation/screens/edit_profil_screen.dart';
import '../../features/akun/presentation/screens/ganti_password_screen.dart';
import '../../features/beranda/presentation/screens/analisis_performa_screen.dart';
import '../../features/enrollment/presentation/screens/paket_saya_screen.dart';
import '../../features/katalog/data/models/package_model.dart';
import '../../features/katalog/presentation/screens/katalog_screen.dart';
import '../../features/katalog/presentation/screens/tryout_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/privasi/presentation/screens/privasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/subscription/presentation/screens/langganan_screen.dart';
import '../../features/transaksi/presentation/screens/checkout_webview_screen.dart';
import '../../features/transaksi/presentation/screens/riwayat_transaksi_screen.dart';
import '../../features/transaksi/presentation/screens/transaksi_detail_screen.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/register/form' ||
          loc == '/check-email' ||
          loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash) return '/login';
          if (isAuthRoute) return null;
          return '/login';
        },
        authenticated: (_) {
          if (isSplash || isAuthRoute) return '/home';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/register/form',
        builder: (_, __) => const RegisterFormScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/akun/edit-profil',
        builder: (_, __) => const EditProfilScreen(),
      ),
      GoRoute(
        path: '/akun/ganti-password',
        builder: (_, __) => const GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/privasi',
        builder: (_, __) => const PrivasiScreen(),
      ),
      GoRoute(
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
      ),
      GoRoute(
        path: '/transaksi',
        builder: (_, __) => const RiwayatTransaksiScreen(),
      ),
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransaksiDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/langganan',
        builder: (_, __) => const LangganganScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final args = state.extra as CheckoutArgs;
          return CheckoutWebViewScreen(transactionId: args.transactionId, snapToken: args.snapToken);
        },
      ),
      GoRoute(
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
      ),
      GoRoute(
        path: '/katalog',
        builder: (context, state) {
          final filter = state.extra as PackageType?;
          return KatalogScreen(initialFilter: filter);
        },
      ),
      GoRoute(
        path: '/latihan-soal',
        builder: (_, __) => const LatihanKategoriScreen(),
      ),
      GoRoute(
        path: '/latihan-soal/kategori/:taxonomyId',
        builder: (context, state) {
          final taxonomyId = int.parse(state.pathParameters['taxonomyId']!);
          final categoryName = state.extra as String?;
          return LatihanTopikScreen(taxonomyId: taxonomyId, categoryName: categoryName);
        },
      ),
      GoRoute(
        path: '/latihan-soal/topik/:topicId',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['topicId']!);
          final topicName = state.extra as String?;
          return LatihanRoadmapScreen(topicId: topicId, topicName: topicName);
        },
      ),
      GoRoute(
        path: '/paket/:packageId/exams',
        builder: (context, state) {
          final packageId = int.parse(state.pathParameters['packageId']!);
          return ExamListScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/exams/:examId/summary',
        builder: (context, state) {
          final examId = int.parse(state.pathParameters['examId']!);
          return ExamSummaryScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamAttemptScreen(attemptId: attemptId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId/review',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamReviewScreen(attemptId: attemptId);
        },
      ),
    ],
  );
}

EOF_ROUTER

echo 'Modul Privasi (toggle hide_from_leaderboard_feed) selesai dibangun.'
