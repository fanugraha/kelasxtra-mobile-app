// lib/features/exam_engine/presentation/screens/my_exams_screen.dart
//
// GET /my-exams -- "Semua Ujian": semua exam try-out yang boleh diakses
// siswa, LINTAS SEMUA paket yang dipunya (beda dari ExamListScreen yang
// scoped ke 1 paket lewat GET /packages/{package}/exams). Ini jawaban
// untuk masalah "user yang beli 3-4 paket harus buka satu-satu untuk cek
// mana yang belum dikerjakan".
//
// CATATAN SCOPE: payload endpoint ini TIDAK membawa status pengerjaan
// (attempts_count/skor) -- lihat catatan lengkap di [MyExamItem]. Jadi
// layar ini murni "daftar semua ujian yang bisa kamu akses", status
// sudah-dikerjakan-atau-belum baru kelihatan setelah tap masuk ke
// ExamSummaryScreen (yang sudah fetch attempts_count dari GET
// /exams/{exam}/summary). Kalau nanti backend nambah status per-item di
// endpoint ini, cukup tambah field di model + badge di _ExamCard, tidak
// perlu ubah struktur layar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

class MyExamsScreen extends ConsumerWidget {
  const MyExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(myExamsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Semua Ujian'),
      ),
      body: examsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat daftar ujian',
          onRetry: () => ref.invalidate(myExamsProvider),
        ),
        data: (exams) {
          if (exams.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myExamsProvider),
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
  final MyExamItem exam;

  @override
  Widget build(BuildContext context) {
    // >1 bank = try-out gabungan (mis. TWK+TIU+TKP dalam 1 attempt) --
    // TETAP 1 tap, TETAP 1 nilai gabungan, cuma dikasih catatan supaya
    // siswa tidak bingung kenapa 1 ujian sebut beberapa nama bank.
    final isMultiBank = exam.availableBanks.length > 1;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.timer_outlined, color: AppColors.brand500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.title,
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
                      const Icon(Icons.schedule, size: 12, color: AppColors.neutral500),
                      const SizedBox(width: 3),
                      Text(
                        '${exam.durationMinutes} menit',
                        style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                      ),
                      if (exam.questionsCount != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.list_alt_outlined, size: 12, color: AppColors.neutral500),
                        const SizedBox(width: 3),
                        Text(
                          '${exam.questionsCount} soal',
                          style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                  if (exam.isFreePreview || isMultiBank) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (exam.isFreePreview)
                          const _Badge(label: 'Gratis Preview', color: AppColors.success600),
                        if (isMultiBank)
                          _Badge(
                            label: 'Gabungan ${exam.availableBanks.length} Bank',
                            color: AppColors.gold600,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
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
            const Icon(Icons.quiz_outlined, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada ujian yang bisa diakses',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Beli paket try-out untuk mulai berlatih.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push('/katalog'),
              child: const Text('Lihat Katalog'),
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
