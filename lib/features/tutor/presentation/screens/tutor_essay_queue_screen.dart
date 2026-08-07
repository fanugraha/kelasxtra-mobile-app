// lib/features/tutor/presentation/screens/tutor_essay_queue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/tutor_provider.dart';

class TutorEssayQueueScreen extends ConsumerWidget {
  const TutorEssayQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(tutorEssayQueueNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Penilaian Essay'),
      ),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final isForbidden = error is ApiException && error.isForbidden;
          return _ErrorState(
            message: isForbidden
                ? 'Kamu tidak punya akses ke halaman ini.'
                : (error is ApiException ? error.message : 'Gagal memuat antrian penilaian'),
            onRetry: isForbidden
                ? null
                : () => ref.read(tutorEssayQueueNotifierProvider.notifier).refresh(),
          );
        },
        data: (items) {
          if (items.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () => ref.read(tutorEssayQueueNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _EssayCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _EssayCard extends ConsumerStatefulWidget {
  const _EssayCard({required this.item});
  final TutorEssayQueueItem item;

  @override
  ConsumerState<_EssayCard> createState() => _EssayCardState();
}

class _EssayCardState extends ConsumerState<_EssayCard> {
  bool _isSubmitting = false;

  Future<void> _handleGrade(bool isCorrect) async {
    setState(() => _isSubmitting = true);
    final error = await ref
        .read(tutorEssayQueueNotifierProvider.notifier)
        .gradeEssay(answerId: widget.item.id, isCorrect: isCorrect);

    if (!mounted) return;
    if (error != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    // Kalau sukses, item ini sudah dihapus dari list oleh notifier
    // (optimistic) -- widget ini otomatis ke-unmount lewat rebuild
    // ListView.separated, tidak perlu setState _isSubmitting=false lagi.
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final studentName = item.attempt?.user?.name ?? 'Siswa';

    return Container(
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
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.brand50,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.brand600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studentName,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.questionText ?? '(soal tidak bisa ditampilkan)',
            style: TextStyle(
              color: item.questionText != null ? AppColors.neutral700 : AppColors.neutral400,
              fontSize: 13,
              fontStyle: item.questionText != null ? FontStyle.normal : FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.essayAnswer?.trim().isNotEmpty == true
                  ? item.essayAnswer!
                  : '(jawaban kosong)',
              style: const TextStyle(color: AppColors.neutral900, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleGrade(false),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.danger600),
                  label: const Text('Salah', style: TextStyle(color: AppColors.danger600)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger100)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleGrade(true),
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Benar'),
                ),
              ),
            ],
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
            const Icon(Icons.task_alt, color: AppColors.success600, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada essay yang perlu dinilai',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Semua jawaban essay sudah dinilai. Kerja bagus!',
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
  final VoidCallback? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      ),
    );
  }
}
