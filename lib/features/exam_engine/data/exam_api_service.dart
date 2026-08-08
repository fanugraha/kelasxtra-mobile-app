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
import 'models/exam_review_model.dart';
import 'models/exam_summary_model.dart';
import 'models/my_exam_model.dart';
import 'models/topic_mastery_model.dart';

part 'exam_api_service.g.dart';

class ExamApiService {
  ExamApiService(this._dio);

  final Dio _dio;

  /// Laravel API Resource (dipakai buat ExamAttempt) otomatis membungkus
  /// response jadi `{"data": {...}}` secara default -- TERVERIFIKASI dari
  /// response asli POST /exams/start (log 30 Jul 2026). Endpoint lain yang
  /// nulis response manual (mis. /exams/{id}/summary, /packages/{id}/exams)
  /// TIDAK dibungkus. Helper ini defensif: pakai `data['data']` kalau ada
  /// dan berupa Map, kalau tidak fallback ke `data` itu sendiri -- supaya
  /// tidak crash lagi kalau ternyata beberapa endpoint attempt lain
  /// polanya beda.
  Map<String, dynamic> _unwrap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final inner = map['data'];
    if (inner is Map<String, dynamic>) return inner;
    return map;
  }

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
    return ExamAttemptModel.fromJson(_unwrap(response.data));
  }

  /// GET /exam-attempts/{id} -- dipakai untuk resume / polling timer /
  /// ganti section.
  Future<ExamAttemptModel> getAttempt(int attemptId) async {
    final response = await _dio.get(ApiEndpoints.examAttemptDetail(attemptId));
    return ExamAttemptModel.fromJson(_unwrap(response.data));
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
    final data = _unwrap(response.data);
    return data['tab_switch_count'] as int? ?? 0;
  }

  /// POST /exam-attempts/{id}/finish -- submit manual. Hasil status=graded
  /// kalau tidak ada essay pending, submitted kalau masih ada essay yang
  /// perlu dinilai tutor.
  Future<ExamAttemptModel> finishAttempt(int attemptId) async {
    final response = await _dio.post(ApiEndpoints.examAttemptFinish(attemptId));
    return ExamAttemptModel.fromJson(_unwrap(response.data));
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

  /// GET /exam-attempts/{id}/review -- pembahasan per soal. Struktur
  /// diverifikasi dari response asli 31 Jul 2026 (lihat catatan tri-state
  /// `is_correct` dan kasus khusus TKP di [ExamReviewQuestion]).
  Future<ExamReviewModel> getReview(int attemptId) async {
    final response = await _dio.get(ApiEndpoints.examAttemptReview(attemptId));
    return ExamReviewModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /me/topic-performance?program_id= -- ranking semua topik dalam 1
  /// program, terlemah dulu (backend sudah sort, jangan sort ulang di
  /// client). [programId] wajib -- lihat catatan validasi di backend
  /// (ExamController::topicPerformance).
  Future<TopicPerformanceResponse> getTopicPerformance(int programId) async {
    final response = await _dio.get(
      ApiEndpoints.topicPerformance,
      queryParameters: {'program_id': programId},
    );
    return TopicPerformanceResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /me/topic-mastery-history?topic_id=&periods= -- riwayat mastery
  /// mingguan 1 topik. [periods] maksimal 52 di server (default 12).
  /// program_id TIDAK dikirim -- backend menurunkannya sendiri dari
  /// topic.taxonomy.program_id.
  Future<TopicMasteryHistoryModel> getTopicMasteryHistory({
    required int topicId,
    int periods = 12,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.topicMasteryHistory,
      queryParameters: {'topic_id': topicId, 'periods': periods},
    );
    return TopicMasteryHistoryModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /my-exams -- semua exam try-out yang boleh diakses siswa, LINTAS
  /// SEMUA paket yang dipunya (bukan cuma 1 paket seperti getPackageExams).
  /// Response array polos (bukan dibungkus {"data": ...}) -- lihat catatan
  /// di [MyExamItem] soal cakupan field-nya.
  Future<List<MyExamItem>> getMyExams() async {
    final response = await _dio.get(ApiEndpoints.myExams);
    final data = response.data as List<dynamic>;
    return data.map((json) => MyExamItem.fromJson(json as Map<String, dynamic>)).toList();
  }
}

@Riverpod(keepAlive: true)
ExamApiService examApiService(ExamApiServiceRef ref) {
  return ExamApiService(ref.watch(dioProvider));
}
