// lib/features/exam_engine/presentation/screens/topic_performance_screen.dart
//
// GET /me/topic-performance?program_id= -- "Semua Topik": ranking topik
// terlemah-dulu LINTAS SEMUA EXAM dalam 1 program (beda dari
// AnalisisPerformaScreen yang mengelompokkan per section/exam). Backend
// (ExamController::topicPerformance) sudah mengurutkan topik yang datanya
// cukup dari yang paling lemah, dan menaruh topik yang datanya belum
// cukup di akhir -- urutan ini SENGAJA dipertahankan apa adanya di sini
// (tidak di-group per kategori/section), supaya makna "urutan prioritas
// belajar" dari backend tidak hilang.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

/// extra untuk route '/analisis-performa/topik' -- programId wajib
/// (dipakai query GET /me/topic-performance), programName cuma untuk
/// judul AppBar.
class TopicPerformanceArgs {
  const TopicPerformanceArgs({required this.programId, this.programName});
  final int programId;
  final String? programName;
}

class TopicPerformanceScreen extends ConsumerWidget {
  const TopicPerformanceScreen({super.key, required this.programId, this.programName});

  final int programId;
  final String? programName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(topicPerformanceProvider(programId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(programName != null ? 'Semua Topik -- $programName' : 'Semua Topik'),
      ),
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat performa topik',
          onRetry: () => ref.invalidate(topicPerformanceProvider(programId)),
        ),
        data: (performance) {
          if (performance.attemptsIncluded == 0 || performance.topics.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(topicPerformanceProvider(programId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: performance.topics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _TopicPerformanceCard(item: performance.topics[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TopicPerformanceCard extends StatelessWidget {
  const _TopicPerformanceCard({required this.item});
  final TopicPerformanceItem item;

  @override
  Widget build(BuildContext context) {
    final hasData = item.hasEnoughData;
    final pct = item.percentage;
    final color = !hasData
        ? AppColors.neutral400
        : pct != null && pct < 60
            ? AppColors.danger600
            : pct != null && pct < 80
                ? AppColors.gold600
                : AppColors.success600;

    final trendIcon = switch (item.trend) {
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      'stable' => Icons.trending_flat,
      _ => null,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/analisis-performa/topik/${item.topicId}',
        extra: item.topicName,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.category != null)
              Container(
                margin: const EdgeInsets.only(top: 1, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category!.code ?? item.category!.name,
                  style: const TextStyle(
                    color: AppColors.brand600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.topicName,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasData
                        ? '${item.correctCount}/${item.totalCount} soal benar'
                        : 'Baru ${item.totalCount} soal -- kerjakan lebih banyak untuk lihat performa',
                    style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    hasData ? '${pct!.toStringAsFixed(0)}%' : 'Belum Cukup',
                    style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (trendIcon != null) ...[
                  const SizedBox(height: 4),
                  Icon(trendIcon, size: 16, color: color),
                ],
              ],
            ),
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
            const Icon(Icons.query_stats_outlined, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data topik',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kerjakan try-out di program ini untuk melihat performa per topik.',
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
