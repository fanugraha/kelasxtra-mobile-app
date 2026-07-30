// lib/features/exam_engine/presentation/providers/exam_provider.dart
//
// Provider Fase 2 (Pre-Exam Flow): fetch tunggal, family per id, tidak
// perlu Notifier class -- polanya sama seperti kenapa EnrollmentApiService
// raw Dio (bukan Retrofit): sederhana, jangan over-engineer sebelum ada
// kebutuhan nyata. State machine attempt (Fase 3) baru butuh Notifier.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/exam_repository.dart';
import '../../data/models/exam_summary_model.dart';

export '../../data/models/exam_summary_model.dart';

part 'exam_provider.g.dart';

/// GET /exams/{exam}/summary. [bankId] opsional untuk try-out multi-bank.
@riverpod
Future<ExamSummaryModel> examSummary(ExamSummaryRef ref, int examId, {int? bankId}) {
  return ref.watch(examRepositoryProvider).getExamSummary(examId, bankId: bankId);
}

/// GET /packages/{package}/exams -- lihat catatan verifikasi di
/// [ExamListItemModel].
@riverpod
Future<List<ExamListItemModel>> packageExams(PackageExamsRef ref, int packageId) {
  return ref.watch(examRepositoryProvider).getPackageExams(packageId);
}
