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
