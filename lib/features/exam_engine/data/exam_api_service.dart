// lib/features/exam_engine/data/exam_api_service.dart
//
// Panggilan HTTP mentah untuk Exam Engine. Ikuti pola EnrollmentApiService /
// NotifikasiApiService (raw Dio) -- konvensi yang dipakai di semua modul
// terbaru project ini, bukan Retrofit yang dipakai auth di awal-awal.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/exam_attempt_model.dart';
import 'models/exam_summary_model.dart';

part 'exam_api_service.g.dart';

class ExamApiService {
  ExamApiService(this._dio);

  final Dio _dio;

  /// POST /exams/start -- rate limit 10/menit di server.
  /// [examBatchId] kosongkan untuk mode latihan soal.
  /// [bankId] untuk try-out multi-bank.
  /// Attempt in_progress untuk kombinasi exam+batch+bank yang sama akan
  /// di-resume otomatis oleh server, bukan bikin attempt baru.
  Future<ExamAttemptModel> startExam({
    required int examId,
    int? examBatchId,
    int? bankId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.examsStart,
      data: {
        'exam_id': examId,
        if (examBatchId != null) 'exam_batch_id': examBatchId,
        if (bankId != null) 'bank_id': bankId,
      },
    );
    return ExamAttemptModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exam-attempts/{id} -- dipakai untuk resume / polling timer /
  /// ganti section.
  Future<ExamAttemptModel> getAttempt(int attemptId) async {
    final response = await _dio.get(ApiEndpoints.examAttemptDetail(attemptId));
    return ExamAttemptModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /exam-attempts/{id}/answer -- auto-save 1 jawaban. Rate limit
  /// 60/menit di server -- caller (repository/provider) bertanggung jawab
  /// throttle di sisi client supaya tidak kena limit.
  /// Isi salah satu: [selectedOptionId] (soal type=pg) atau [essayAnswer]
  /// (soal type=essay).
  Future<void> submitAnswer({
    required int attemptId,
    required int questionId,
    int? selectedOptionId,
    String? essayAnswer,
  }) async {
    await _dio.post(
      ApiEndpoints.examAttemptAnswer(attemptId),
      data: {
        'question_id': questionId,
        if (selectedOptionId != null) 'selected_option_id': selectedOptionId,
        if (essayAnswer != null) 'essay_answer': essayAnswer,
      },
    );
  }

  /// POST /exam-attempts/{id}/tab-switch -- panggil setiap AppLifecycleState
  /// berubah ke paused/inactive saat attempt in_progress. Tidak menghentikan
  /// attempt, cuma dicatat untuk review admin/tutor.
  Future<int> reportTabSwitch(int attemptId) async {
    final response = await _dio.post(ApiEndpoints.examAttemptTabSwitch(attemptId));
    final data = response.data as Map<String, dynamic>;
    return data['tab_switch_count'] as int? ?? 0;
  }

  /// POST /exam-attempts/{id}/finish -- submit manual. Hasil status=graded
  /// kalau tidak ada essay pending, submitted kalau masih ada essay yang
  /// perlu dinilai tutor.
  Future<ExamAttemptModel> finishAttempt(int attemptId) async {
    final response = await _dio.post(ApiEndpoints.examAttemptFinish(attemptId));
    return ExamAttemptModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exams/{exam}/summary -- ringkasan untuk screen pra-ujian
  /// (attempt in-progress, jumlah percobaan, skor pertama & terakhir).
  /// [bankId] opsional untuk try-out multi-bank.
  Future<ExamSummaryModel> getExamSummary(int examId, {int? bankId}) async {
    final response = await _dio.get(
      ApiEndpoints.examSummary(examId),
      queryParameters: bankId != null ? {'bank_id': bankId} : null,
    );
    return ExamSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /packages/{package}/exams -- daftar exam dalam 1 paket. Endpoint
  /// ini `x-verified: inferred` -- lihat catatan di [ExamListItemModel]
  /// sebelum dipakai untuk hal kritikal.
  Future<List<ExamListItemModel>> getPackageExams(int packageId) async {
    final response = await _dio.get(ApiEndpoints.packageExams(packageId));
    final data = response.data as List<dynamic>;
    return data
        .map((json) => ExamListItemModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /exam-attempts/{id}/review -- struktur ditandai `x-verified:
  /// inferred` di spec, BELUM dimodelkan jadi freezed class. Sengaja
  /// dikembalikan sebagai Map mentah -- panggil manual (curl/Postman)
  /// begitu ada attempt berstatus graded, baru desain model & UI-nya
  /// (rencana Fase 5).
  Future<Map<String, dynamic>> getReview(int attemptId) async {
    final response = await _dio.get(ApiEndpoints.examAttemptReview(attemptId));
    return response.data as Map<String, dynamic>;
  }
}

@Riverpod(keepAlive: true)
ExamApiService examApiService(ExamApiServiceRef ref) {
  return ExamApiService(ref.watch(dioProvider));
}
