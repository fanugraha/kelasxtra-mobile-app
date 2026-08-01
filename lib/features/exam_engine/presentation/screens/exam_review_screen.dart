// lib/features/exam_engine/presentation/screens/exam_review_screen.dart
//
// Fase 5 -- TAHAP 1. GET /exam-attempts/{id}/review ditandai
// `x-verified: inferred` TANPA schema sama sekali di spec (bukan cuma field
// yang meleset seperti kasus /packages/{id}/exams kemarin -- literally
// belum pernah ditelusuri). Daripada menebak bentuk pembahasan per-soal
// (resiko field salah tinggi, UI harus dirombak ulang kalau meleset),
// screen ini SENGAJA cuma nampilkan JSON mentah + tombol salin, supaya
// begitu ada attempt graded, kamu bisa buka sekali, salin, kirim ke saya --
// baru saya bangun model freezed + UI pembahasan per-soal yang proper
// (Fase 5 TAHAP 2). Ganti file ini sepenuhnya begitu itu selesai.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

class ExamReviewScreen extends ConsumerWidget {
  const ExamReviewScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(examReviewProvider(attemptId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Pembahasan (mode debug)'),
        actions: [
          reviewAsync.maybeWhen(
            data: (review) => IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: 'Salin JSON',
              onPressed: () => _copyToClipboard(context, review),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat pembahasan',
          onRetry: () => ref.invalidate(examReviewProvider(attemptId)),
        ),
        data: (review) => Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand500.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Halaman sementara: tampilan pembahasan per-soal yang '
                'rapi masih dibangun. Tap ikon salin di kanan atas, kirim '
                'JSON ini supaya bisa dilanjutkan ke tampilan final.',
                style: TextStyle(color: AppColors.neutral500, fontSize: 12),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(review),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.neutral900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, Map<String, dynamic> review) {
    final pretty = const JsonEncoder.withIndent('  ').convert(review);
    Clipboard.setData(ClipboardData(text: pretty));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('JSON pembahasan disalin.')),
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
