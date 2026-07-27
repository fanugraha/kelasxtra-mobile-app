import 'package:flutter/material.dart';

/// TODO: home screen -- rekomendasi paket (GET /packages/recommended),
/// tombol lanjutkan exam (GET /my-exams/latest-attempted), promo banner, dst.
class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Beranda Screen')),
    );
  }
}
