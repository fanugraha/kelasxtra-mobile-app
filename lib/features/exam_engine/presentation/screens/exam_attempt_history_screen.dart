// lib/features/exam_engine/presentation/screens/exam_attempt_history_screen.dart
//
// GET /exams/{exam}/attempts -- "Riwayat Semua Percobaan": beda dari
// ExamSummaryScreen yang cuma tampilkan percobaan pertama & terakhir, layar
// ini nampilin SEMUA percobaan yang sudah selesai (submitted/auto_submitted/
// graded), diurutkan attempt_number ASC. Dibuka lewat link "Lihat Semua
// Riwayat Percobaan" di ExamSummaryScreen -- cuma muncul kalau
// attemptsCount > 0 di sana.
//
// Style kartu sengaja dibuat mirip _AttemptCard di ExamSummaryScreen (badge
// lulus/tidak, breakdown skor per section) supaya konsisten, ditambah label
// "Percobaan ke-N" dan tanggal pengerjaan yang tidak ada di summary.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/exam_provider.dart';

class ExamAttemptHistoryScreen extends ConsumerWidget {
  const ExamAttemptHistoryScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(examAttemptHistoryProvider(examId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Riwayat Percobaan'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat riwayat percobaan',
          onRetry: () => ref.invalidate(examAttemptHistoryProvider(examId)),
        ),
        data: (history) {
          if (history.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(examAttemptHistoryProvider(examId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  history.exam.title,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${history.attempts.length} kali dikerjakan',
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                // Backend urutkan started_at ASC (attempt_number 1 duluan) --
                // tampilan dibalik supaya percobaan TERBARU ada di atas,
                // lebih relevan buat dilihat pertama daripada scroll ke bawah.
                for (final attempt in history.attempts.reversed) ...[
                  _AttemptHistoryCard(attempt: attempt),
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

class _AttemptHistoryCard extends StatelessWidget {
  const _AttemptHistoryCard({required this.attempt});
  final ExamAttemptHistoryItem attempt;

  @override
  Widget build(BuildContext context) {
    final passed = attempt.passed;

    return Container(
      width: double.infinity,
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
                  'Percobaan ke-${attempt.attemptNumber}'
                  '${attempt.bank != null ? ' \u2022 ${attempt.bank!.title}' : ''}',
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (passed != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: passed ? AppColors.success50 : AppColors.danger50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    passed ? 'Lulus' : 'Belum Lulus',
                    style: TextStyle(
                      color: passed ? AppColors.success700 : AppColors.danger600,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            formatTanggal(attempt.finishedAt.toIso8601String()),
            style: const TextStyle(color: AppColors.neutral400, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                attempt.score.toStringAsFixed(0),
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${attempt.correctCount} benar',
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                ),
              ),
            ],
          ),
          if (attempt.sections.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final section in attempt.sections)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      section.name,
                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                    ),
                    Text(
                      '${section.rawScore.toStringAsFixed(0)} '
                      '(${section.correctCount} benar)',
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/exam-attempts/${attempt.attemptId}/review'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('Lihat Pembahasan'),
            ),
          ),
        ],
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
            const Icon(Icons.history, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada percobaan yang selesai',
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
