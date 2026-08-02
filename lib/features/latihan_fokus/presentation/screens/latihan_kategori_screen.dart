// lib/features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanKategoriScreen extends ConsumerWidget {
  const LatihanKategoriScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(latihanCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Latihan Soal per Topik'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat kategori',
          onRetry: () => ref.invalidate(latihanCategoriesProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanCategoriesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  'Pilih mapel, lalu susun roadmap belajarmu topik demi topik.',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final category in categories) ...[
                  _CategoryCard(category: category),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final LatihanCategoryModel category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/latihan-soal/kategori/${category.id}',
        extra: category.name,
      ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (category.program?.name != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      category.program!.name!,
                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.topic_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada kategori latihan soal',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba lagi nanti setelah materi latihan tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
