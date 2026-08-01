// lib/features/exam_engine/presentation/screens/exam_review_screen.dart
//
// Fase 5 tahap 2. Struktur GET /exam-attempts/{id}/review sudah
// terverifikasi (lihat catatan panjang di exam_review_model.dart) --
// screen ini gantikan versi debug (raw JSON) sebelumnya.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';
import '../widgets/question_html_text.dart';

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
        title: const Text('Pembahasan'),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat pembahasan',
          onRetry: () => ref.invalidate(examReviewProvider(attemptId)),
        ),
        data: (review) {
          final questions = review.questions;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: questions.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) return _SummaryHeader(review: review);

              final question = questions[index - 1];
              final prevCategory = index >= 2 ? questions[index - 2].category.code : null;
              final showCategoryHeader = question.category.code != prevCategory;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCategoryHeader)
                    Padding(
                      padding: EdgeInsets.only(top: index == 1 ? 0 : 20, bottom: 10),
                      child: Text(
                        question.category.name,
                        style: const TextStyle(
                          color: AppColors.brand600,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  _QuestionReviewCard(index: index, question: question),
                  const SizedBox(height: 12),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.review});
  final ExamReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            review.examTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                review.score.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                '${review.correctCount} dari ${review.questions.length} soal benar',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({required this.index, required this.question});

  final int index;
  final ExamReviewQuestion question;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No. $index',
                style: const TextStyle(
                  color: AppColors.neutral500,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _StatusBadge(question: question),
            ],
          ),
          const SizedBox(height: 8),
          QuestionHtmlText(question.questionText),
          const SizedBox(height: 12),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionRow(question: question, option: option),
            ),
          if (question.explanation != null && question.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.gold600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuestionHtmlText(
                      question.explanation!,
                      style: const TextStyle(color: AppColors.neutral700, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.question});
  final ExamReviewQuestion question;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;

    if (!question.hasAnswerKey) {
      // TKP -- tidak ada benar/salah, cuma status terjawab/tidak.
      bg = question.wasAnswered ? AppColors.neutral100 : AppColors.gold100;
      fg = question.wasAnswered ? AppColors.neutral600 : AppColors.gold600;
      label = question.wasAnswered ? 'Terjawab' : 'Belum Dijawab';
    } else if (!question.wasAnswered) {
      bg = AppColors.gold100;
      fg = AppColors.gold600;
      label = 'Belum Dijawab';
    } else if (question.isCorrect == true) {
      bg = AppColors.success50;
      fg = AppColors.success700;
      label = 'Benar';
    } else {
      bg = AppColors.danger50;
      fg = AppColors.danger600;
      label = 'Salah';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.question, required this.option});

  final ExamReviewQuestion question;
  final ExamReviewOption option;

  @override
  Widget build(BuildContext context) {
    final isSelected = option.id == question.selectedOptionId;

    // TKP tidak punya kunci jawaban -- cuma tandai pilihan user, tanpa
    // sinyal benar/salah (lihat catatan hasAnswerKey di model).
    if (!question.hasAnswerKey) {
      return _buildRow(
        borderColor: isSelected ? AppColors.brand500 : AppColors.neutral200,
        bgColor: isSelected ? AppColors.brand50 : Colors.white,
        icon: isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        iconColor: isSelected ? AppColors.brand500 : AppColors.neutral400,
        textColor: isSelected ? AppColors.brand600 : AppColors.neutral700,
      );
    }

    if (option.isCorrect) {
      return _buildRow(
        borderColor: AppColors.success600,
        bgColor: AppColors.success50,
        icon: Icons.check_circle,
        iconColor: AppColors.success600,
        textColor: AppColors.success700,
      );
    }
    if (isSelected) {
      // Dipilih user tapi salah.
      return _buildRow(
        borderColor: AppColors.danger600,
        bgColor: AppColors.danger50,
        icon: Icons.cancel,
        iconColor: AppColors.danger600,
        textColor: AppColors.danger700,
      );
    }
    return _buildRow(
      borderColor: AppColors.neutral200,
      bgColor: Colors.white,
      icon: Icons.radio_button_unchecked,
      iconColor: AppColors.neutral400,
      textColor: AppColors.neutral700,
    );
  }

  Widget _buildRow({
    required Color borderColor,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              option.optionText,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
            ),
          ),
        ],
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
