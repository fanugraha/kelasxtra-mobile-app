// lib/features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanRoadmapScreen extends ConsumerWidget {
  const LatihanRoadmapScreen({super.key, required this.topicId, this.topicName});

  final int topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(latihanRoadmapProvider(topicId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(topicName ?? 'Roadmap'),
      ),
      body: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat roadmap',
          onRetry: () => ref.invalidate(latihanRoadmapProvider(topicId)),
        ),
        data: (parts) {
          if (parts.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanRoadmapProvider(topicId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                for (int i = 0; i < parts.length; i++) ...[
                  _RoadmapPartCard(part: parts[i], sequenceNumber: i + 1),
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

class _RoadmapPartCard extends StatelessWidget {
  const _RoadmapPartCard({required this.part, required this.sequenceNumber});
  final LatihanRoadmapPartModel part;
  final int sequenceNumber;

  void _handleTap(BuildContext context) {
    switch (part.status) {
      case LatihanRoadmapPartStatus.completed:
      case LatihanRoadmapPartStatus.unlocked:
        context.push('/exams/${part.examId}/summary');
        break;
      case LatihanRoadmapPartStatus.lockedSequence:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selesaikan part sebelumnya dulu untuk membuka ini.')),
        );
        break;
      case LatihanRoadmapPartStatus.lockedSubscription:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Part ini butuh paket berlangganan aktif.')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = part.status == LatihanRoadmapPartStatus.completed;
    final isLocked = part.isLocked;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleTap(context),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success50
                    : (isLocked ? AppColors.neutral100 : AppColors.brand50),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, color: AppColors.success700, size: 18)
                  : isLocked
                      ? const Icon(Icons.lock_outline, color: AppColors.neutral400, size: 16)
                      : Text(
                          '$sequenceNumber',
                          style: const TextStyle(
                            color: AppColors.brand600,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.title,
                    style: TextStyle(
                      color: isLocked ? AppColors.neutral500 : AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.neutral400, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${part.durationMinutes} menit',
                        style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                      ),
                      if (part.bestScore != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.emoji_events_outlined,
                            color: AppColors.neutral400, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          'Skor ${part.bestScore!.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                        ),
                      ],
                      if (part.isFreePreview) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.gold100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Pratinjau Gratis',
                            style: TextStyle(
                              color: AppColors.gold600,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock_outline : Icons.chevron_right,
              color: AppColors.neutral400,
              size: isLocked ? 16 : 22,
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
            const Icon(Icons.route_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada part latihan di topik ini',
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
