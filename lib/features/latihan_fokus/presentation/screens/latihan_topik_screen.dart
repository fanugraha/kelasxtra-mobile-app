// lib/features/latihan_fokus/presentation/screens/latihan_topik_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanTopikScreen extends ConsumerWidget {
  const LatihanTopikScreen({super.key, required this.taxonomyId, this.categoryName});

  final int taxonomyId;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(latihanTopicsProvider(taxonomyId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(categoryName ?? 'Topik'),
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat topik',
          onRetry: () => ref.invalidate(latihanTopicsProvider(taxonomyId)),
        ),
        data: (topics) {
          if (topics.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanTopicsProvider(taxonomyId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                for (final topic in topics) ...[
                  _TopicCard(topic: topic),
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

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});
  final LatihanTopicModel topic;

  @override
  Widget build(BuildContext context) {
    final isDone = topic.isFullyCompleted;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/latihan-soal/topik/${topic.topicId}',
        extra: topic.name,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.name,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        color: AppColors.success700,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: topic.progressRatio,
                minHeight: 6,
                backgroundColor: AppColors.neutral100,
                color: isDone ? AppColors.success600 : AppColors.brand500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${topic.completedParts}/${topic.totalParts} part selesai',
              style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
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
            const Icon(Icons.topic_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada topik di kategori ini',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
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
