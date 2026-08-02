import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// TODO: Try Out dan Materi masih menyusul. Latihan Soal per Topik sudah
/// jadi (lihat lib/features/latihan_fokus/), diarahkan dari sini.
class LatihanScreen extends StatelessWidget {
  const LatihanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        automaticallyImplyLeading: false,
        title: const Text('Latihan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/latihan-soal'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.topic_outlined, color: AppColors.brand500, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latihan Soal per Topik',
                          style: TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Susun roadmap topik demi topik',
                          style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.neutral400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top_outlined, color: AppColors.neutral400, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tryout dan Materi segera hadir',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
