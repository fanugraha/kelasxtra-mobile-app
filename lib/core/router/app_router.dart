import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
// TODO: import screen beranda saat modul beranda/katalog sudah dibuat.

part 'app_router.g.dart';

/// Notifier kecil yang cuma bertugas "membangunkan" GoRouter tiap kali
/// authNotifierProvider berubah, supaya redirect logic dievaluasi ulang.
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
      final isAuthRoute = loc == '/login' || loc == '/register' || loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash || isAuthRoute || loc == '/check-email') return isSplash ? '/login' : null;
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
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return _CheckEmailPlaceholder(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const _NotImplementedPlaceholder(title: 'Lupa Password'),
      ),
      // TODO: ganti dengan HomeScreen sungguhan dari modul beranda.
      GoRoute(
        path: '/home',
        builder: (_, __) => const _NotImplementedPlaceholder(title: 'Beranda'),
      ),
    ],
  );
}

class _CheckEmailPlaceholder extends StatelessWidget {
  const _CheckEmailPlaceholder({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cek Email Anda')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Link verifikasi sudah dikirim ke $email. Silakan cek inbox/spam.'),
        ),
      ),
    );
  }
}

class _NotImplementedPlaceholder extends StatelessWidget {
  const _NotImplementedPlaceholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — belum diimplementasikan.')),
    );
  }
}
