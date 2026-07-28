import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// TODO: halaman profil lengkap (edit profil, langganan aktif, logout) --
/// didesain menyusul setelah Beranda selesai. Tombol logout disertakan
/// sekarang supaya alur auth bisa ditest end-to-end.
class AkunScreen extends ConsumerWidget {
  const AkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Akun — segera hadir', style: TextStyle(color: AppColors.neutral500)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
