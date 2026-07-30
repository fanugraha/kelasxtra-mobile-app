// lib/features/exam_engine/presentation/screens/exam_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key, required this.packageId});

  final int packageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(packageExamsProvider(packageId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Daftar Ujian'),
      ),
      body: examsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat daftar ujian',
          onRetry: () => ref.invalidate(packageExamsProvider(packageId)),
        ),
        data: (exams) {
          if (exams.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(packageExamsProvider(packageId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ExamCard(exam: exams[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final ExamListItemModel exam;

  @override
  Widget build(BuildContext context) {
    final title = exam.title ?? 'Ujian #${exam.id}';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/exams/${exam.id}/summary'),
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
                color: AppColors.brand500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                exam.hasInProgressAttempt ? Icons.play_circle_outline : Icons.timer_outlined,
                color: AppColors.brand500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (exam.durationMinutes != null) ...[
                        const Icon(Icons.schedule, size: 12, color: AppColors.neutral500),
                        const SizedBox(width: 3),
                        Text(
                          '${exam.durationMinutes} menit',
                          style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (exam.attemptsCount != null && exam.attemptsCount! > 0)
                        Text(
                          '${exam.attemptsCount}x dikerjakan',
                          style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                        ),
                    ],
                  ),
                  if (exam.hasInProgressAttempt) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Sedang dikerjakan',
                      style: TextStyle(
                        color: AppColors.brand600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
            const Icon(Icons.quiz_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada ujian di paket ini',
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
