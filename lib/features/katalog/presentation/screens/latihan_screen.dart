import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// TODO: pusat Try Out, Latihan Soal, dan Materi -- didesain menyusul
/// setelah Beranda selesai.
class LatihanScreen extends StatelessWidget {
  const LatihanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text('Latihan — segera hadir', style: TextStyle(color: AppColors.neutral500)),
      ),
    );
  }
}
