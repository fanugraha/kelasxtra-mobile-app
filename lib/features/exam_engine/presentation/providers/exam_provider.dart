// lib/features/exam_engine/presentation/providers/exam_provider.dart
//
// Provider Fase 2 (Pre-Exam Flow): fetch tunggal, family per id, tidak
// perlu Notifier class -- polanya sama seperti kenapa EnrollmentApiService
// raw Dio (bukan Retrofit): sederhana, jangan over-engineer sebelum ada
// kebutuhan nyata. State machine attempt (Fase 3) baru butuh Notifier.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/exam_repository.dart';
import '../../data/models/exam_attempt_history_model.dart';
import '../../data/models/exam_review_model.dart';
import '../../data/models/exam_summary_model.dart';
import '../../data/models/my_exam_model.dart';
import '../../data/models/topic_mastery_model.dart';

export '../../data/models/exam_attempt_history_model.dart';
export '../../data/models/exam_review_model.dart';
export '../../data/models/exam_summary_model.dart';
export '../../data/models/my_exam_model.dart';
export '../../data/models/topic_mastery_model.dart';

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

/// GET /exam-attempts/{id}/review -- pembahasan per soal (model
/// terverifikasi, lihat [ExamReviewModel]).
@riverpod
Future<ExamReviewModel> examReview(ExamReviewRef ref, int attemptId) {
  return ref.watch(examRepositoryProvider).getReview(attemptId);
}

/// GET /me/topic-performance?program_id= -- ranking topik terlemah-dulu
/// dalam 1 program. Dipakai layar "Semua Topik" (drill-down dari
/// Analisis Performa).
@riverpod
Future<TopicPerformanceResponse> topicPerformance(TopicPerformanceRef ref, int programId) {
  return ref.watch(examRepositoryProvider).getTopicPerformance(programId);
}

/// GET /me/topic-mastery-history?topic_id= -- riwayat mingguan 1 topik
/// (chart tren). access.full=false -> periods dikembalikan kosong oleh
/// backend, ditangani di layar (lihat TopicMasteryHistoryScreen).
@riverpod
Future<TopicMasteryHistoryModel> topicMasteryHistory(TopicMasteryHistoryRef ref, int topicId) {
  return ref.watch(examRepositoryProvider).getTopicMasteryHistory(topicId: topicId);
}

/// GET /my-exams -- semua exam try-out yang boleh diakses siswa, lintas
/// semua paket yang dipunya. Dipakai MyExamsScreen ("Semua Ujian").
@riverpod
Future<List<MyExamItem>> myExams(MyExamsRef ref) {
  return ref.watch(examRepositoryProvider).getMyExams();
}

/// GET /exams/{exam}/attempts -- riwayat SEMUA percobaan (bukan cuma
/// pertama/terakhir seperti examSummary). Dipakai ExamAttemptHistoryScreen,
/// di-buka dari link "Lihat Semua Riwayat" di ExamSummaryScreen. [bankId]
/// opsional untuk try-out multi-bank.
@riverpod
Future<ExamAttemptHistoryResponse> examAttemptHistory(
  ExamAttemptHistoryRef ref,
  int examId, {
  int? bankId,
}) {
  return ref.watch(examRepositoryProvider).getExamAttempts(examId, bankId: bankId);
}
