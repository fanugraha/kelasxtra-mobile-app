#!/usr/bin/env bash
set -euo pipefail

mkdir -p lib/core/router lib/features/beranda/presentation/screens lib/features/exam_engine/data lib/features/exam_engine/data/models lib/features/exam_engine/presentation/providers lib/features/exam_engine/presentation/screens

cat > lib/features/exam_engine/data/models/topic_mastery_model.dart << 'EOF_0_topic_mastery_model_dart'
// lib/features/exam_engine/data/models/topic_mastery_model.dart
//
// Model untuk GET /me/topic-performance dan GET /me/topic-mastery-history.
// x-verified: source-code -- dicocokkan langsung ke
// ExamController::topicPerformance() dan PerformanceController::
// topicMasteryHistory() di kelasxtra-backend (bukan cuma openapi.yaml,
// yang untuk topic-performance masih `x-verified: inferred`/schema
// generik). Dua endpoint ini SENGAJA dipisah backend (lihat komentar di
// topicMasteryHistory()): topic-performance ngasih ranking semua topik
// dalam 1 program (buat layar "Semua Topik"), topic-mastery-history
// ngasih time-series 1 topik (buat chart drill-down) -- makanya modelnya
// juga dipisah di sini walau sama-sama soal "mastery topik".
import 'package:freezed_annotation/freezed_annotation.dart';

part 'topic_mastery_model.freezed.dart';
part 'topic_mastery_model.g.dart';

// ==================== GET /me/topic-performance ====================

@freezed
class TopicPerformanceCategory with _$TopicPerformanceCategory {
  const factory TopicPerformanceCategory({
    required int id,
    String? code,
    required String name,
  }) = _TopicPerformanceCategory;

  factory TopicPerformanceCategory.fromJson(Map<String, dynamic> json) =>
      _$TopicPerformanceCategoryFromJson(json);
}

@freezed
class TopicPerformanceItem with _$TopicPerformanceItem {
  const factory TopicPerformanceItem({
    @JsonKey(name: 'topic_id') required int topicId,
    @JsonKey(name: 'topic_code') String? topicCode,
    @JsonKey(name: 'topic_name') required String topicName,
    TopicPerformanceCategory? category,
    @JsonKey(name: 'correct_count') required int correctCount,
    @JsonKey(name: 'total_count') required int totalCount,
    // false = sample_size < 5 soal -- backend taruh topik ini di ujung
    // list (bukan diurut berdasar percentage yang bisa menyesatkan kalau
    // sample-nya kecil, mis. 1/2 soal salah = 50%). Tampilkan state
    // "belum cukup data" di UI, JANGAN tampilkan percentage seolah valid.
    @JsonKey(name: 'has_enough_data') required bool hasEnoughData,
    // Persentase akumulasi SEMUA attempt. Null kalau !hasEnoughData.
    double? percentage,
    // Persentase dari attempt-attempt PALING BARU saja (lihat $recentSample
    // di backend) -- dipakai buat hitung trend, bukan buat ditampilkan
    // sebagai angka utama (angka utama tetap [percentage]).
    @JsonKey(name: 'recent_percentage') double? recentPercentage,
    // 'up' | 'down' | 'stable' | null. Null kalau data belum cukup ATAU
    // recentTotal >= total (belum ada attempt lama utk dibandingkan).
    String? trend,
  }) = _TopicPerformanceItem;

  factory TopicPerformanceItem.fromJson(Map<String, dynamic> json) =>
      _$TopicPerformanceItemFromJson(json);
}

@freezed
class TopicPerformanceResponse with _$TopicPerformanceResponse {
  const factory TopicPerformanceResponse({
    @JsonKey(name: 'program_id') required int programId,
    @JsonKey(name: 'attempts_included') required int attemptsIncluded,
    @Default(<TopicPerformanceItem>[]) List<TopicPerformanceItem> topics,
  }) = _TopicPerformanceResponse;

  factory TopicPerformanceResponse.fromJson(Map<String, dynamic> json) =>
      _$TopicPerformanceResponseFromJson(json);
}

// ==================== GET /me/topic-mastery-history ====================

@freezed
class TopicMasteryTopicRef with _$TopicMasteryTopicRef {
  const factory TopicMasteryTopicRef({
    required int id,
    String? code,
    required String name,
  }) = _TopicMasteryTopicRef;

  factory TopicMasteryTopicRef.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryTopicRefFromJson(json);
}

@freezed
class TopicMasteryPeriod with _$TopicMasteryPeriod {
  const factory TopicMasteryPeriod({
    // Format "2026-W29" (ISO week) -- lihat _formatPeriode/_formatPeriodeSingkat
    // di topic_mastery_history_screen.dart untuk cara parse-nya ke UI.
    required String period,
    @JsonKey(name: 'correct_count') required int correctCount,
    @JsonKey(name: 'total_count') required int totalCount,
    required double percentage,
    String? trend,
    @JsonKey(name: 'computed_at') DateTime? computedAt,
  }) = _TopicMasteryPeriod;

  factory TopicMasteryPeriod.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryPeriodFromJson(json);
}

@freezed
class TopicMasteryUpgradeCta with _$TopicMasteryUpgradeCta {
  const factory TopicMasteryUpgradeCta({
    required String message,
    @JsonKey(name: 'action_link') String? actionLink,
  }) = _TopicMasteryUpgradeCta;

  factory TopicMasteryUpgradeCta.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryUpgradeCtaFromJson(json);
}

@freezed
class TopicMasteryAccess with _$TopicMasteryAccess {
  const factory TopicMasteryAccess({
    required bool full,
    @JsonKey(name: 'upgrade_cta') TopicMasteryUpgradeCta? upgradeCta,
  }) = _TopicMasteryAccess;

  factory TopicMasteryAccess.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryAccessFromJson(json);
}

/// access.full=false -- backend sengaja balikin `periods: []` kosong,
/// BUKAN 403 -- supaya UI tetap bisa tampilkan nama topik + upgrade CTA
/// tanpa request kedua. Enrollment/subscription penuh ke program terkait
/// (lihat AccessControlService::hasFullPerformanceAccess di backend)
/// wajib buat lihat riwayat mingguan -- preview/free-trial TIDAK cukup,
/// beda dari topic-performance yang tidak ada gating sama sekali.
@freezed
class TopicMasteryHistoryModel with _$TopicMasteryHistoryModel {
  const factory TopicMasteryHistoryModel({
    required TopicMasteryTopicRef topic,
    @Default(<TopicMasteryPeriod>[]) List<TopicMasteryPeriod> periods,
    required TopicMasteryAccess access,
  }) = _TopicMasteryHistoryModel;

  factory TopicMasteryHistoryModel.fromJson(Map<String, dynamic> json) =>
      _$TopicMasteryHistoryModelFromJson(json);
}
EOF_0_topic_mastery_model_dart

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
import '../../data/models/topic_mastery_model.dart';

export '../../data/models/exam_review_model.dart';
export '../../data/models/exam_summary_model.dart';
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
EOF_3_exam_provider_dart

cat > lib/features/exam_engine/presentation/screens/topic_mastery_history_screen.dart << 'EOF_4_topic_mastery_history_screen_dart'
// lib/features/exam_engine/presentation/screens/topic_mastery_history_screen.dart
//
// GET /me/topic-mastery-history -- grafik tren mastery mingguan 1 topik.
// Chart di-hand-roll pakai Container biasa (bukan pakai package chart
// baru seperti fl_chart) -- data time-series-nya sederhana (<=52 titik,
// cuma butuh bar + label), konsisten dengan gaya project ini yang lebih
// suka nulis manual daripada nambah dependency baru untuk hal sederhana
// (lihat catatan di core/utils/formatters.dart soal DateFormat).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

class TopicMasteryHistoryScreen extends ConsumerWidget {
  const TopicMasteryHistoryScreen({super.key, required this.topicId, this.topicName});

  final int topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(topicMasteryHistoryProvider(topicId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(topicName != null ? 'Riwayat -- $topicName' : 'Riwayat Mastery'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat riwayat mastery',
          onRetry: () => ref.invalidate(topicMasteryHistoryProvider(topicId)),
        ),
        data: (history) {
          if (!history.access.full) {
            return _LockedState(cta: history.access.upgradeCta);
          }
          if (history.periods.isEmpty) {
            return const _NoHistoryState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(topicMasteryHistoryProvider(topicId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _LatestSnapshotCard(latest: history.periods.last),
                const SizedBox(height: 20),
                const Text(
                  'Tren Mingguan',
                  style: TextStyle(color: AppColors.neutral900, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _MasteryChart(periods: history.periods),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LatestSnapshotCard extends StatelessWidget {
  const _LatestSnapshotCard({required this.latest});
  final TopicMasteryPeriod latest;

  @override
  Widget build(BuildContext context) {
    final trendIcon = switch (latest.trend) {
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      _ => Icons.trending_flat,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mastery Minggu Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${latest.percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latest.correctCount}/${latest.totalCount} soal benar -- ${_formatPeriode(latest.period)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(trendIcon, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

/// Chart bar sederhana -- 1 kolom per periode, tinggi bar proporsional ke
/// percentage (0-100). Discroll horizontal kalau periode-nya banyak
/// (server bisa balikin sampai 52 minggu).
class _MasteryChart extends StatelessWidget {
  const _MasteryChart({required this.periods});
  final List<TopicMasteryPeriod> periods;

  static const _chartHeight = 140.0;
  static const _barWidth = 28.0;
  static const _columnWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // langsung scroll ke periode terbaru (kanan)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final period in periods) _ChartColumn(period: period),
          ],
        ),
      ),
    );
  }
}

class _ChartColumn extends StatelessWidget {
  const _ChartColumn({required this.period});
  final TopicMasteryPeriod period;

  @override
  Widget build(BuildContext context) {
    final pct = period.percentage.clamp(0, 100).toDouble();
    final color = pct < 60
        ? AppColors.danger600
        : pct < 80
            ? AppColors.gold600
            : AppColors.success600;
    final barHeight = (_MasteryChart._chartHeight - 34) * (pct / 100);

    return SizedBox(
      width: _MasteryChart._columnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pct.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            width: _MasteryChart._barWidth,
            height: barHeight.clamp(2.0, _MasteryChart._chartHeight).toDouble(),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPeriodeSingkat(period.period),
            style: const TextStyle(color: AppColors.neutral500, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

/// "2026-W29" -> "Minggu ke-29, 2026"
String _formatPeriode(String period) {
  final match = RegExp(r'^(\d{4})-W(\d{1,2})$').firstMatch(period);
  if (match == null) return period;
  return 'Minggu ke-${int.parse(match.group(2)!)}, ${match.group(1)}';
}

/// "2026-W29" -> "W29" (label sumbu-x, harus ringkas)
String _formatPeriodeSingkat(String period) {
  final match = RegExp(r'^\d{4}-W(\d{1,2})$').firstMatch(period);
  if (match == null) return period;
  return 'W${match.group(1)}';
}

class _LockedState extends StatelessWidget {
  const _LockedState({required this.cta});
  final TopicMasteryUpgradeCta? cta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.gold600, size: 44),
            const SizedBox(height: 14),
            Text(
              cta?.message ?? 'Riwayat mastery lengkap terkunci -- upgrade paket untuk membukanya.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral700, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              // action_link dari backend berformat path web, tidak match
              // route Flutter app ini -- arahkan ke Paket Saya seperti pola
              // yang sama dipakai di AnalisisPerformaScreen.
              onPressed: () => context.push('/paket-saya'),
              child: const Text('Lihat Paket Saya'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHistoryState extends StatelessWidget {
  const _NoHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada riwayat mingguan',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Riwayat mastery terbentuk tiap minggu dari latihan soal topik ini.',
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
EOF_4_topic_mastery_history_screen_dart

cat > lib/features/exam_engine/presentation/screens/topic_performance_screen.dart << 'EOF_5_topic_performance_screen_dart'
// lib/features/exam_engine/presentation/screens/topic_performance_screen.dart
//
// GET /me/topic-performance?program_id= -- "Semua Topik": ranking topik
// terlemah-dulu LINTAS SEMUA EXAM dalam 1 program (beda dari
// AnalisisPerformaScreen yang mengelompokkan per section/exam). Backend
// (ExamController::topicPerformance) sudah mengurutkan topik yang datanya
// cukup dari yang paling lemah, dan menaruh topik yang datanya belum
// cukup di akhir -- urutan ini SENGAJA dipertahankan apa adanya di sini
// (tidak di-group per kategori/section), supaya makna "urutan prioritas
// belajar" dari backend tidak hilang.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

/// extra untuk route '/analisis-performa/topik' -- programId wajib
/// (dipakai query GET /me/topic-performance), programName cuma untuk
/// judul AppBar.
class TopicPerformanceArgs {
  const TopicPerformanceArgs({required this.programId, this.programName});
  final int programId;
  final String? programName;
}

class TopicPerformanceScreen extends ConsumerWidget {
  const TopicPerformanceScreen({super.key, required this.programId, this.programName});

  final int programId;
  final String? programName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(topicPerformanceProvider(programId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(programName != null ? 'Semua Topik -- $programName' : 'Semua Topik'),
      ),
      body: performanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat performa topik',
          onRetry: () => ref.invalidate(topicPerformanceProvider(programId)),
        ),
        data: (performance) {
          if (performance.attemptsIncluded == 0 || performance.topics.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(topicPerformanceProvider(programId)),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: performance.topics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _TopicPerformanceCard(item: performance.topics[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TopicPerformanceCard extends StatelessWidget {
  const _TopicPerformanceCard({required this.item});
  final TopicPerformanceItem item;

  @override
  Widget build(BuildContext context) {
    final hasData = item.hasEnoughData;
    final pct = item.percentage;
    final color = !hasData
        ? AppColors.neutral400
        : pct != null && pct < 60
            ? AppColors.danger600
            : pct != null && pct < 80
                ? AppColors.gold600
                : AppColors.success600;

    final trendIcon = switch (item.trend) {
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      'stable' => Icons.trending_flat,
      _ => null,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/analisis-performa/topik/${item.topicId}',
        extra: item.topicName,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.category != null)
              Container(
                margin: const EdgeInsets.only(top: 1, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brand500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category!.code ?? item.category!.name,
                  style: const TextStyle(
                    color: AppColors.brand600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.topicName,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasData
                        ? '${item.correctCount}/${item.totalCount} soal benar'
                        : 'Baru ${item.totalCount} soal -- kerjakan lebih banyak untuk lihat performa',
                    style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    hasData ? '${pct!.toStringAsFixed(0)}%' : 'Belum Cukup',
                    style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (trendIcon != null) ...[
                  const SizedBox(height: 4),
                  Icon(trendIcon, size: 16, color: color),
                ],
              ],
            ),
          ],
        ),
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
            const Icon(Icons.query_stats_outlined, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data topik',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kerjakan try-out di program ini untuk melihat performa per topik.',
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
EOF_5_topic_performance_screen_dart

cat > lib/core/router/app_router.dart << 'EOF_6_app_router_dart'
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
EOF_6_app_router_dart

cat > lib/features/beranda/presentation/screens/analisis_performa_screen.dart << 'EOF_7_analisis_performa_screen_dart'
// lib/features/beranda/presentation/screens/analisis_performa_screen.dart
//
// Konsumsi PerformanceSummary yang sudah di-fetch Beranda (berandaNotifierProvider)
// -- SENGAJA tidak panggil GET /me/performance-summary sendiri, supaya buka
// layar ini tidak nambah 1 request lagi selain yang sudah dilakukan Beranda.
// Konsekuensinya: data di sini seusia data Beranda terakhir; pull-to-refresh
// di sini memicu refresh Beranda juga (lewat BerandaNotifier.refresh()).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../exam_engine/presentation/screens/topic_performance_screen.dart';
import '../providers/beranda_provider.dart';

class AnalisisPerformaScreen extends ConsumerWidget {
  const AnalisisPerformaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Analisis Performa'),
      ),
      body: berandaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat data performa',
          onRetry: () => ref.read(berandaNotifierProvider.notifier).refresh(),
        ),
        data: (beranda) {
          final performance = beranda.performance;
          return RefreshIndicator(
            onRefresh: () => ref.read(berandaNotifierProvider.notifier).refresh(),
            child: switch (performance.state) {
              PerformanceState.noAttempts => _NoAttemptsState(cta: performance.cta),
              PerformanceState.insufficientAttempts =>
                _PerformanceBody(performance: performance, showInsufficientBanner: true),
              PerformanceState.ready =>
                _PerformanceBody(performance: performance, showInsufficientBanner: false),
            },
          );
        },
      ),
    );
  }
}

class _NoAttemptsState extends StatelessWidget {
  const _NoAttemptsState({required this.cta});
  final PerformanceCta? cta;

  @override
  Widget build(BuildContext context) {
    // ListView (bukan Column+Center) supaya RefreshIndicator tetap bisa
    // di-pull walau kontennya pendek/tidak scrollable.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.query_stats_outlined, size: 56, color: AppColors.neutral300),
        const SizedBox(height: 16),
        Text(
          cta?.message ?? 'Belum ada data try-out untuk dianalisis.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.neutral700, fontSize: 14, height: 1.5),
        ),
        if (cta != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              // action_link dari backend berformat path web (mis.
              // "/app/packages?..."), tidak match route Flutter app ini --
              // arahkan ke Paket Saya (Fase 0, sudah ada) sebagai tujuan
              // paling relevan yang benar-benar ada saat ini.
              onPressed: () => context.push('/paket-saya'),
              child: const Text('Lihat Paket Saya'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PerformanceBody extends StatelessWidget {
  const _PerformanceBody({required this.performance, required this.showInsufficientBanner});

  final PerformanceSummary performance;
  final bool showInsufficientBanner;

  @override
  Widget build(BuildContext context) {
    final access = performance.access;
    final showUpgradeBanner = access != null && !access.full && access.upgradeCta != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _StreakCard(streak: performance.streak),
        // Link ke "Semua Topik" (GET /me/topic-performance) -- ranking
        // topik LINTAS SEMUA EXAM dalam program ini, beda dari
        // sections di bawah yang dikelompokkan per section/exam.
        // programId wajib untuk query itu, jadi disembunyikan kalau
        // backend tidak mengirim `program` (mis. belum ada attempt sama
        // sekali -- state itu ditangani _NoAttemptsState, bukan di sini,
        // tapi dijaga juga untuk kondisi lain yang tidak terduga).
        if (performance.program != null) ...[
          const SizedBox(height: 14),
          _AllTopicsLink(programId: performance.program!.id, programName: performance.program!.name),
        ],
        if (showInsufficientBanner) ...[
          const SizedBox(height: 14),
          const _InfoBanner(
            icon: Icons.info_outline,
            text:
                'Data kamu masih terbatas -- kerjakan lebih banyak try-out supaya analisis per topik lebih akurat.',
          ),
        ],
        if (showUpgradeBanner) ...[
          const SizedBox(height: 14),
          _UpgradeBanner(cta: access.upgradeCta!),
        ],
        if (performance.topRecommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Rekomendasi Belajar'),
          const SizedBox(height: 10),
          for (final rec in performance.topRecommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationCard(recommendation: rec),
            ),
        ],
        if (performance.sections.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Peta Kekuatan per Section'),
          const SizedBox(height: 10),
          for (final section in performance.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SectionCard(section: section),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.neutral900,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streak.count} hari beruntun',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak.activeToday
                      ? 'Sudah belajar hari ini, pertahankan!'
                      : 'Belum belajar hari ini -- yuk lanjutkan streak-mu.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTopicsLink extends StatelessWidget {
  const _AllTopicsLink({required this.programId, required this.programName});
  final int programId;
  final String programName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/analisis-performa/topik',
        extra: TopicPerformanceArgs(programId: programId, programName: programName),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            const Icon(Icons.list_alt_outlined, size: 18, color: AppColors.brand600),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Lihat Semua Topik',
                style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.neutral500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.neutral600, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.cta});
  final PerformanceCta cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold500),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.gold600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cta.message,
              style: const TextStyle(color: AppColors.gold600, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          // Lihat catatan action_link di _NoAttemptsState -- sama-sama
          // diarahkan ke Paket Saya, bukan mengikuti action_link mentah.
          TextButton(
            onPressed: () => context.push('/paket-saya'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold600,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});
  final TopRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // practice_link dari backend belum match route app ini (lihat catatan
      // di _NoAttemptsState), jadi tidak dipakai. Push langsung pakai
      // recommendation.topicId ke roadmap topik terkait -- diverifikasi
      // topic_id di sini pakai id Topic model yang sama dengan route model
      // binding /latihan-soal/topics/{topic}/roadmap di backend
      // (TopicPracticeController::roadmap), jadi aman dipakai langsung.
      onTap: () => context.push(
        '/latihan-soal/topik/${recommendation.topicId}',
        extra: recommendation.topicName,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recommendation.sectionCode,
                style: const TextStyle(
                  color: AppColors.brand600,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.topicName,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.message,
                    style: const TextStyle(color: AppColors.neutral600, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final PerformanceSection section;

  @override
  Widget build(BuildContext context) {
    // gap_to_pass nullable di spec -- kalau null (mis. section ini tidak
    // ada ambang kelulusan terpisah), sembunyikan baris gap sama sekali
    // daripada menampilkan angka yang menyesatkan (mis. "0" seolah sudah
    // pas di batas).
    final gap = section.gapToPass;

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
              Expanded(
                child: Text(
                  section.name,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: section.isPassed ? AppColors.success50 : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  section.isPassed ? 'Lulus' : 'Belum Lulus',
                  style: TextStyle(
                    color: section.isPassed ? AppColors.success700 : AppColors.neutral600,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            section.minPassingScore != null
                ? 'Skor: ${section.currentScore.toStringAsFixed(0)} / ${section.minPassingScore} (ambang lulus)'
                : 'Skor: ${section.currentScore.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
          ),
          if (gap != null && gap > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Kurang $gap poin lagi untuk lulus section ini.',
              style: const TextStyle(color: AppColors.gold600, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          if (section.topicsLocked)
            const _LockedTopicsPlaceholder()
          else
            for (final topic in section.topics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TopicRow(topic: topic),
              ),
        ],
      ),
    );
  }
}

class _LockedTopicsPlaceholder extends StatelessWidget {
  const _LockedTopicsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.neutral400),
          SizedBox(width: 6),
          Text(
            'Detail per topik terkunci -- upgrade paket untuk membukanya',
            style: TextStyle(color: AppColors.neutral500, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});
  final PerformanceTopic topic;

  @override
  Widget build(BuildContext context) {
    final color = switch (topic.level) {
      TopicLevel.weak => AppColors.danger600,
      TopicLevel.medium => AppColors.gold600,
      TopicLevel.strong => AppColors.success600,
      TopicLevel.insufficientData => AppColors.neutral400,
    };

    final trend = topic.trend;
    final trendIcon = switch (trend) {
      TopicTrend.up => Icons.trending_up,
      TopicTrend.down => Icons.trending_down,
      TopicTrend.stable => Icons.trending_flat,
      null => null,
    };

    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            topic.name,
            style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5),
          ),
        ),
        if (trendIcon != null) ...[
          Icon(trendIcon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(
            topic.percentage != null ? '${topic.percentage}% -- ${topic.label}' : topic.label,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
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
EOF_7_analisis_performa_screen_dart

echo "Selesai. Jalankan: dart run build_runner build --delete-conflicting-outputs"
