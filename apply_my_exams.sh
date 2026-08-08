#!/usr/bin/env bash
set -euo pipefail

mkdir -p lib/core/router lib/features/akun/presentation/screens lib/features/exam_engine/data lib/features/exam_engine/data/models lib/features/exam_engine/presentation/providers lib/features/exam_engine/presentation/screens

cat > lib/features/exam_engine/data/models/my_exam_model.dart << 'EOF_0_my_exam_model_dart'
// lib/features/exam_engine/data/models/my_exam_model.dart
//
// Model untuk GET /my-exams. x-verified: source-code -- dicocokkan langsung
// ke ExamController::myExams() di kelasxtra-backend (openapi.yaml masih
// `x-verified: inferred`/schema generik untuk endpoint ini).
//
// PENTING: endpoint ini CUMA daftar exam yang boleh diakses siswa (hasil
// filter AccessControlService::canAttemptExam(), lintas SEMUA paket yang
// dipunya) -- TIDAK ada info status pengerjaan (sudah dikerjakan/belum,
// skor) di payload-nya, beda dari asumsi awal "Riwayat Ujian". Status itu
// baru didapat per-exam lewat GET /exams/{exam}/summary (attempts_count,
// first_attempt, latest_attempt) -- makanya tap di MyExamsScreen tetap
// diarahkan ke ExamSummaryScreen yang sudah ada, bukan menampilkan status
// langsung di kartu list.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_exam_model.freezed.dart';
part 'my_exam_model.g.dart';

@freezed
class MyExamBank with _$MyExamBank {
  const factory MyExamBank({
    required int id,
    required String title,
    @JsonKey(name: 'questions_count') @Default(0) int questionsCount,
  }) = _MyExamBank;

  factory MyExamBank.fromJson(Map<String, dynamic> json) => _$MyExamBankFromJson(json);
}

@freezed
class MyExamItem with _$MyExamItem {
  const factory MyExamItem({
    required int id,
    required String title,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    @JsonKey(name: 'questions_count') int? questionsCount,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    // Null kalau exam ini tidak terhubung ke bank soal manapun (edge case
    // konten belum lengkap) -- backend ambil program_ids[0] sebagai
    // representatif, TIDAK selalu berarti exam ini cuma 1 program.
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'program_ids') @Default(<int>[]) List<int> programIds,
    // >1 = exam ini gabungan beberapa Question Bank (mis. TWK+TIU+TKP
    // dalam 1 try-out) -- TETAP 1 attempt/1 nilai gabungan (lihat catatan
    // di ExamController::forPackage), bukan sinyal untuk modal pilih bank.
    @JsonKey(name: 'available_banks') @Default(<MyExamBank>[]) List<MyExamBank> availableBanks,
  }) = _MyExamItem;

  const MyExamItem._();

  factory MyExamItem.fromJson(Map<String, dynamic> json) => _$MyExamItemFromJson(json);
}
EOF_0_my_exam_model_dart

cat > lib/features/exam_engine/data/exam_api_service.dart << 'EOF_1_exam_api_service_dart'
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
EOF_1_exam_api_service_dart

cat > lib/features/exam_engine/data/exam_repository.dart << 'EOF_2_exam_repository_dart'
// lib/features/exam_engine/data/exam_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'exam_api_service.dart';
import 'models/exam_attempt_model.dart';
import 'models/exam_review_model.dart';
import 'models/exam_summary_model.dart';
import 'models/my_exam_model.dart';
import 'models/topic_mastery_model.dart';

part 'exam_repository.g.dart';

class ExamRepository {
  ExamRepository(this._api);

  final ExamApiService _api;

  /// Lempar [ApiException] biasa untuk error umum. Untuk 2 kasus khusus,
  /// cek lewat getter di ApiException sebelum tampilkan message mentah:
  /// - `e.isPreviousPartIncomplete` (403, Latihan Fokus part sebelumnya
  ///   belum selesai)
  /// - `e.isValidationError` dengan `e.batchStartAt`/`e.batchEndAt` terisi
  ///   (422, try-out batch belum buka/sudah tutup)
  Future<ExamAttemptModel> startExam({
    required int examId,
    int? examBatchId,
    int? bankId,
  }) async {
    try {
      return await _api.startExam(
        examId: examId,
        examBatchId: examBatchId,
        bankId: bankId,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamAttemptModel> getAttempt(int attemptId) async {
    try {
      return await _api.getAttempt(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Lempar [ApiException] dengan `isValidationError=true` kalau waktu
  /// habis / attempt sudah tidak aktif / soal bukan bagian section aktif
  /// -- caller (provider Fase 3) perlu treat ini sebagai sinyal untuk
  /// redirect ke finish/review, bukan sekadar tampilkan error dan retry.
  Future<void> submitAnswer({
    required int attemptId,
    required int questionId,
    int? selectedOptionId,
    String? essayAnswer,
  }) async {
    try {
      await _api.submitAnswer(
        attemptId: attemptId,
        questionId: questionId,
        selectedOptionId: selectedOptionId,
        essayAnswer: essayAnswer,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Sengaja tidak melempar ApiException -- kegagalan lapor tab-switch
  /// bukan hal fatal untuk pengalaman user, jangan sampai ganggu ujian
  /// yang sedang berjalan. Return null kalau request gagal.
  Future<int?> reportTabSwitch(int attemptId) async {
    try {
      return await _api.reportTabSwitch(attemptId);
    } on DioException catch (_) {
      return null;
    }
  }

  Future<ExamAttemptModel> finishAttempt(int attemptId) async {
    try {
      return await _api.finishAttempt(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamSummaryModel> getExamSummary(int examId, {int? bankId}) async {
    try {
      return await _api.getExamSummary(examId, bankId: bankId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ExamListItemModel>> getPackageExams(int packageId) async {
    try {
      return await _api.getPackageExams(packageId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamReviewModel> getReview(int attemptId) async {
    try {
      return await _api.getReview(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TopicPerformanceResponse> getTopicPerformance(int programId) async {
    try {
      return await _api.getTopicPerformance(programId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TopicMasteryHistoryModel> getTopicMasteryHistory({
    required int topicId,
    int periods = 12,
  }) async {
    try {
      return await _api.getTopicMasteryHistory(topicId: topicId, periods: periods);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MyExamItem>> getMyExams() async {
    try {
      return await _api.getMyExams();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
ExamRepository examRepository(ExamRepositoryRef ref) {
  return ExamRepository(ref.watch(examApiServiceProvider));
}
EOF_2_exam_repository_dart

cat > lib/features/exam_engine/presentation/providers/exam_provider.dart << 'EOF_3_exam_provider_dart'
// lib/features/exam_engine/presentation/providers/exam_provider.dart
//
// Provider Fase 2 (Pre-Exam Flow): fetch tunggal, family per id, tidak
// perlu Notifier class -- polanya sama seperti kenapa EnrollmentApiService
// raw Dio (bukan Retrofit): sederhana, jangan over-engineer sebelum ada
// kebutuhan nyata. State machine attempt (Fase 3) baru butuh Notifier.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/exam_repository.dart';
import '../../data/models/exam_review_model.dart';
import '../../data/models/exam_summary_model.dart';
import '../../data/models/my_exam_model.dart';
import '../../data/models/topic_mastery_model.dart';

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
EOF_3_exam_provider_dart

cat > lib/features/exam_engine/presentation/screens/my_exams_screen.dart << 'EOF_4_my_exams_screen_dart'
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
EOF_4_my_exams_screen_dart

cat > lib/core/router/app_router.dart << 'EOF_5_app_router_dart'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_form_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/akun/presentation/screens/edit_profil_screen.dart';
import '../../features/akun/presentation/screens/ganti_password_screen.dart';
import '../../features/beranda/presentation/screens/analisis_performa_screen.dart';
import '../../features/enrollment/presentation/screens/paket_saya_screen.dart';
import '../../features/katalog/data/models/package_model.dart';
import '../../features/katalog/presentation/screens/katalog_screen.dart';
import '../../features/katalog/presentation/screens/tryout_screen.dart';
import '../../features/kelas_materi/presentation/screens/kelas_detail_screen.dart';
import '../../features/kelas_materi/presentation/screens/kelas_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/exam_engine/presentation/screens/my_exams_screen.dart';
import '../../features/exam_engine/presentation/screens/topic_performance_screen.dart';
import '../../features/exam_engine/presentation/screens/topic_mastery_history_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/privasi/presentation/screens/privasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/subscription/presentation/screens/langganan_screen.dart';
import '../../features/transaksi/presentation/screens/checkout_webview_screen.dart';
import '../../features/transaksi/presentation/screens/riwayat_transaksi_screen.dart';
import '../../features/transaksi/presentation/screens/transaksi_detail_screen.dart';
import '../../features/tutor/presentation/screens/tutor_essay_queue_screen.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/register/form' ||
          loc == '/check-email' ||
          loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash) return '/login';
          if (isAuthRoute) return null;
          return '/login';
        },
        authenticated: (_) {
          if (isSplash || isAuthRoute) return '/home';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/register/form',
        builder: (_, __) => const RegisterFormScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/akun/edit-profil',
        builder: (_, __) => const EditProfilScreen(),
      ),
      GoRoute(
        path: '/akun/ganti-password',
        builder: (_, __) => const GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/privasi',
        builder: (_, __) => const PrivasiScreen(),
      ),
      GoRoute(
        path: '/tutor/essay-queue',
        builder: (_, __) => const TutorEssayQueueScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (_, __) => const KelasListScreen(),
      ),
      GoRoute(
        path: '/classes/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return KelasDetailScreen(classId: id);
        },
      ),
      GoRoute(
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/analisis-performa/topik',
        builder: (context, state) {
          final args = state.extra as TopicPerformanceArgs;
          return TopicPerformanceScreen(programId: args.programId, programName: args.programName);
        },
      ),
      GoRoute(
        path: '/analisis-performa/topik/:topicId',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['topicId']!);
          final topicName = state.extra as String?;
          return TopicMasteryHistoryScreen(topicId: topicId, topicName: topicName);
        },
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
      ),
      GoRoute(
        path: '/semua-ujian',
        builder: (_, __) => const MyExamsScreen(),
      ),
      GoRoute(
        path: '/transaksi',
        builder: (_, __) => const RiwayatTransaksiScreen(),
      ),
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransaksiDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/langganan',
        builder: (_, __) => const LangganganScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final args = state.extra as CheckoutArgs;
          return CheckoutWebViewScreen(transactionId: args.transactionId, snapToken: args.snapToken);
        },
      ),
      GoRoute(
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
      ),
      GoRoute(
        path: '/katalog',
        builder: (context, state) {
          final filter = state.extra as PackageType?;
          return KatalogScreen(initialFilter: filter);
        },
      ),
      GoRoute(
        path: '/latihan-soal',
        builder: (_, __) => const LatihanKategoriScreen(),
      ),
      GoRoute(
        path: '/latihan-soal/kategori/:taxonomyId',
        builder: (context, state) {
          final taxonomyId = int.parse(state.pathParameters['taxonomyId']!);
          final categoryName = state.extra as String?;
          return LatihanTopikScreen(taxonomyId: taxonomyId, categoryName: categoryName);
        },
      ),
      GoRoute(
        path: '/latihan-soal/topik/:topicId',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['topicId']!);
          final topicName = state.extra as String?;
          return LatihanRoadmapScreen(topicId: topicId, topicName: topicName);
        },
      ),
      GoRoute(
        path: '/paket/:packageId/exams',
        builder: (context, state) {
          final packageId = int.parse(state.pathParameters['packageId']!);
          return ExamListScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/exams/:examId/summary',
        builder: (context, state) {
          final examId = int.parse(state.pathParameters['examId']!);
          return ExamSummaryScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamAttemptScreen(attemptId: attemptId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId/review',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamReviewScreen(attemptId: attemptId);
        },
      ),
    ],
  );
}
EOF_5_app_router_dart

cat > lib/features/akun/presentation/screens/akun_screen.dart << 'EOF_6_akun_screen_dart'
// lib/features/akun/presentation/screens/akun_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

class AkunScreen extends ConsumerWidget {
  const AkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

    // Fallback jaga-jaga -- AppShell (lewat redirect di app_router.dart)
    // seharusnya cuma bisa dicapai kalau authState = authenticated, tapi
    // ini menghindari null-check crash kalau state berubah tepat di frame
    // yang sama (mis. race dengan logout / token expired).
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 20),
            if (user.emailVerifiedAt == null) ...[
              const _EmailNotVerifiedBanner(),
              const SizedBox(height: 20),
            ],
            const _SubscriptionCard(),
            const SizedBox(height: 20),
            _MenuSection(
              children: [
                _MenuTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Paket Saya',
                  onTap: () => context.push('/paket-saya'),
                ),
                _MenuTile(
                  icon: Icons.quiz_outlined,
                  label: 'Semua Ujian',
                  onTap: () => context.push('/semua-ujian'),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat Transaksi',
                  onTap: () => context.push('/transaksi'),
                ),
                _MenuTile(
                  icon: Icons.person_outline,
                  label: 'Edit Profil',
                  onTap: () => context.push('/akun/edit-profil'),
                ),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Ganti Password',
                  onTap: () => context.push('/akun/ganti-password'),
                ),
                _MenuTile(
                  icon: Icons.shield_outlined,
                  label: 'Privasi',
                  onTap: () => context.push('/privasi'),
                ),
                _MenuTile(
                  icon: Icons.school_outlined,
                  label: 'Kelas',
                  onTap: () => context.push('/classes'),
                ),
                // Cuma tutor/admin -- endpoint-nya sendiri role-gated
                // (403 kalau bukan), ini cuma menyembunyikan menu supaya
                // siswa biasa tidak lihat tombol yang pasti gagal.
                if (user.role == UserRole.tutor || user.role == UserRole.admin)
                  _MenuTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Penilaian Essay',
                    onTap: () => context.push('/tutor/essay-queue'),
                  ),
                // TODO: menu "Ganti Password" di atas seharusnya disembunyikan
                // atau di-disable kalau user login via Google (googleId !=
                // null) -- akun Google tidak punya current_password untuk
                // divalidasi PUT /auth/password. Belum ada percabangan UI
                // untuk ini karena belum ada akun tes Google buat verifikasi
                // response error yang sebenarnya dari backend (422? pesan
                // apa?) -- cek dulu sebelum menambahkan penanganannya.
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.danger600),
                label: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk mengakses akun ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.brand500,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailNotVerifiedBanner extends ConsumerStatefulWidget {
  const _EmailNotVerifiedBanner();

  @override
  ConsumerState<_EmailNotVerifiedBanner> createState() => _EmailNotVerifiedBannerState();
}

class _EmailNotVerifiedBannerState extends ConsumerState<_EmailNotVerifiedBanner> {
  bool _isSending = false;
  bool _sent = false;

  Future<void> _resend(String email) async {
    setState(() => _isSending = true);
    final error = await ref.read(authNotifierProvider.notifier).resendVerificationEmail(email);
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = error == null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (u) => u.email,
          orElse: () => '',
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold500.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.gold600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email belum diverifikasi',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _sent
                      ? 'Link verifikasi baru sudah dikirim ke $email.'
                      : 'Beberapa fitur mungkin terbatas sampai email diverifikasi.',
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 12),
                ),
                if (!_sent) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isSending ? null : () => _resend(email),
                    child: Text(
                      _isSending ? 'Mengirim...' : 'Kirim ulang email verifikasi',
                      style: const TextStyle(
                        color: AppColors.brand500,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sebelumnya kartu ini numpang data dari berandaNotifierProvider (satu-
/// satunya konsumen GET /my-subscription waktu itu). Sekarang lib/features/
/// subscription/ sudah ada provider sendiri (mySubscriptionNotifierProvider),
/// jadi dependency silang ke Beranda dilepas -- kartu ini juga jadi entry
/// point ke layar Langganan (daftar plan + detail).
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(mySubscriptionNotifierProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/langganan'),
      child: subAsync.when(
        data: (subscription) {
          final isActive = subscription != null;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success50 : AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.verified_outlined : Icons.info_outline,
                  color: isActive ? AppColors.success600 : AppColors.neutral500,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'Langganan Aktif' : 'Belum Berlangganan',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.neutral900),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 2),
                        Text(
                          subscription.plan.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        // Gagal-lembut: kalau /my-subscription gagal load (mis. offline), kartu
        // status langganan cukup disembunyikan -- bukan alasan mengganggu
        // seluruh halaman Akun yang isinya hal lain juga (profil, menu, dst).
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, color: AppColors.neutral200),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neutral600, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.neutral900)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 20),
      onTap: onTap,
    );
  }
}
EOF_6_akun_screen_dart

echo "Selesai. Jalankan: dart run build_runner build --delete-conflicting-outputs"
