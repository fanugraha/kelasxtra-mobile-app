// lib/features/exam_engine/presentation/screens/exam_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/exam_repository.dart';
import '../providers/exam_provider.dart';

class ExamSummaryScreen extends ConsumerWidget {
  const ExamSummaryScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(examSummaryProvider(examId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Ringkasan Ujian'),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat ringkasan ujian',
          onRetry: () => ref.invalidate(examSummaryProvider(examId)),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(examSummaryProvider(examId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _ExamInfoCard(summary: summary),
              if (summary.hasBeenAttempted) ...[
                const SizedBox(height: 20),
                const _SectionTitle(title: 'Percobaan Pertama'),
                const SizedBox(height: 10),
                _AttemptCard(attempt: summary.firstAttempt!),
                if (summary.latestAttempt != null &&
                    summary.latestAttempt!.attemptId != summary.firstAttempt!.attemptId) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Percobaan Terakhir'),
                  const SizedBox(height: 10),
                  _AttemptCard(attempt: summary.latestAttempt!),
                ],
              ],
              const SizedBox(height: 24),
              _StartButton(summary: summary, examId: examId),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamInfoCard extends StatelessWidget {
  const _ExamInfoCard({required this.summary});
  final ExamSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final exam = summary.exam;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Text(
                '${exam.durationMinutes} menit',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.repeat, color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Text(
                '${summary.attemptsCount} kali dikerjakan',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
          if (exam.sections.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final section in exam.sections)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      section.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.neutral900,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt});
  final ExamAttemptSummary attempt;

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
              Text(
                attempt.score.toStringAsFixed(0),
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
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
                    section.rawScore.toStringAsFixed(0),
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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

class _StartButton extends ConsumerStatefulWidget {
  const _StartButton({required this.summary, required this.examId});
  final ExamSummaryModel summary;
  final int examId;

  @override
  ConsumerState<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<_StartButton> {
  bool _isStarting = false;

  Future<void> _handleStart() async {
    setState(() => _isStarting = true);

    try {
      final attempt = await ref.read(examRepositoryProvider).startExam(examId: widget.examId);

      if (!mounted) return;
      // Attempt in_progress untuk kombinasi exam+batch+bank yang sama
      // di-resume otomatis oleh server (lihat catatan ExamApiService.startExam),
      // jadi ini juga jalan buat kasus "Lanjutkan" -- bukan cuma "Mulai Ujian".
      context.push('/exam-attempts/${attempt.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      String message = e.message;
      if (e.isPreviousPartIncomplete) {
        message = 'Selesaikan part sebelumnya dulu sebelum mengerjakan ini.';
      } else if (e.isValidationError && (e.batchStartAt != null || e.batchEndAt != null)) {
        message = 'Try-out belum buka atau sudah tutup (batch: '
            '${e.batchStartAt ?? '-'} s.d. ${e.batchEndAt ?? '-'}).';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInProgress = widget.summary.hasInProgressAttempt;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isStarting ? null : _handleStart,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isStarting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(hasInProgress ? 'Lanjutkan' : 'Mulai Ujian'),
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
