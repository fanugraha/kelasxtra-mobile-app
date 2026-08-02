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
import '../../features/katalog/presentation/screens/tryout_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/subscription/presentation/screens/langganan_screen.dart';
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
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
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

