import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// TODO: papan peringkat lengkap -- didesain menyusul setelah Beranda selesai.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text('Peringkat — segera hadir', style: TextStyle(color: AppColors.neutral500)),
      ),
    );
  }
}
