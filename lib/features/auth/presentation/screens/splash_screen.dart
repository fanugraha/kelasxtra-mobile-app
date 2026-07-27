import 'package:flutter/material.dart';

/// Splash sederhana yang tampil selama AuthState masih [unknown].
/// Redirect ke /login atau /home dilakukan oleh GoRouter redirect logic
/// (lihat core/router/app_router.dart), bukan di sini — supaya satu
/// sumber kebenaran untuk navigasi auth-gated.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlutterLogo(size: 64), // TODO: ganti logo KelasXtra
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
