// lib/features/beranda/data/models/beranda_models.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../katalog/data/models/package_model.dart';
import '../../../subscription/data/models/subscription_plan_model.dart';

part 'beranda_models.freezed.dart';
part 'beranda_models.g.dart';

// ==================== /packages/recommended ====================

@freezed
class RecommendedPackagesResponse with _$RecommendedPackagesResponse {
  const factory RecommendedPackagesResponse({
    @JsonKey(name: 'based_on_program_id') int? basedOnProgramId,
    required List<PackageModel> packages,
  }) = _RecommendedPackagesResponse;

  factory RecommendedPackagesResponse.fromJson(Map<String, dynamic> json) =>
      _$RecommendedPackagesResponseFromJson(json);
}

// ==================== /exams/{exam}/summary ====================
@freezed
class ExamSummaryResponse with _$ExamSummaryResponse {
  const factory ExamSummaryResponse({
    required ExamSummaryExam exam,
    @JsonKey(name: 'in_progress_attempt_id') int? inProgressAttemptId,
  }) = _ExamSummaryResponse;

  factory ExamSummaryResponse.fromJson(Map<String, dynamic> json) =>
      _$ExamSummaryResponseFromJson(json);
}

@freezed
class ExamSummaryExam with _$ExamSummaryExam {
  const factory ExamSummaryExam({
    required int id,
    required String title,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
  }) = _ExamSummaryExam;

  factory ExamSummaryExam.fromJson(Map<String, dynamic> json) =>
      _$ExamSummaryExamFromJson(json);
}

@freezed
class ExamAttemptProgress with _$ExamAttemptProgress {
  const factory ExamAttemptProgress({
    // x-verified: source-code (lihat catatan sama di ExamAttemptModel.
    // remainingSeconds) -- desimal di API asli (mis. 5999.053557), BUKAN
    // integer. Sebelumnya di-cast `as int` di getExamAttemptProgress() dan
    // langsung crash runtime tiap kali Beranda dibuka dengan attempt
    // in_progress -- bug nyata, bukan cuma potensi.
    required double remainingSeconds,
    required int durationMinutes,
  }) = _ExamAttemptProgress;
}

@freezed
class ContinueExamData with _$ContinueExamData {
  const factory ContinueExamData({
    required int examId,
    required String title,
    required double progress,
    int? inProgressAttemptId,
  }) = _ContinueExamData;
}

// ==================== /me/performance-summary ====================
//
// x-verified: source-code untuk sebagian besar field (sections, topics,
// top_recommendations, access, cta) -- dicocokkan ke kelasxtra-openapi.yaml
// DAN response asli (31 Jul-1 Agu 2026). streak & ranking TETAP
// x-verified: inferred (lihat sanitizePerformanceSummaryJson di bawah),
// belum berubah dari sebelumnya.

enum PerformanceState {
  @JsonValue('no_attempts')
  noAttempts,
  @JsonValue('insufficient_attempts')
  insufficientAttempts,
  @JsonValue('ready')
  ready,
}

@freezed
class PerformanceProgram with _$PerformanceProgram {
  const factory PerformanceProgram({
    required int id,
    required String name,
  }) = _PerformanceProgram;

  factory PerformanceProgram.fromJson(Map<String, dynamic> json) =>
      _$PerformanceProgramFromJson(json);
}

@freezed
class StreakInfo with _$StreakInfo {
  const factory StreakInfo({
    required int count,
    @JsonKey(name: 'active_today') required bool activeToday,
    @JsonKey(name: 'last_active_date') String? lastActiveDate,
  }) = _StreakInfo;

  factory StreakInfo.fromJson(Map<String, dynamic> json) =>
      _$StreakInfoFromJson(json);
}

@freezed
class RankingInfo with _$RankingInfo {
  const factory RankingInfo({
    required int rank,
    @JsonKey(name: 'total_participants') required int totalParticipants,
    required double percentile,
    @JsonKey(name: 'exam_batch_id') required int examBatchId,
    @JsonKey(name: 'exam_batch_name') String? examBatchName,
    @JsonKey(name: 'generated_at') String? generatedAt,
  }) = _RankingInfo;

  factory RankingInfo.fromJson(Map<String, dynamic> json) =>
      _$RankingInfoFromJson(json);
}

@freezed
class PerformanceCta with _$PerformanceCta {
  const factory PerformanceCta({
    required String message,
    @JsonKey(name: 'action_link') required String actionLink,
  }) = _PerformanceCta;

  factory PerformanceCta.fromJson(Map<String, dynamic> json) =>
      _$PerformanceCtaFromJson(json);
}

enum TopicLevel {
  @JsonValue('weak')
  weak,
  @JsonValue('medium')
  medium,
  @JsonValue('strong')
  strong,
  @JsonValue('insufficient_data')
  insufficientData,
}

enum TopicTrend {
  @JsonValue('up')
  up,
  @JsonValue('down')
  down,
  @JsonValue('stable')
  stable,
}

@freezed
class PerformanceTopic with _$PerformanceTopic {
  const factory PerformanceTopic({
    @JsonKey(name: 'topic_id') required int topicId,
    required String name,
    required TopicLevel level,
    // Label siap-tampil dari backend (mis. "Perlu Fokus", "Sudah Kuat",
    // "Belum Cukup Data") -- pakai ini langsung di UI, jangan hardcode
    // mapping sendiri dari [level] supaya konsisten kalau backend ganti
    // wording.
    required String label,
    int? percentage,
    @JsonKey(name: 'sample_size') required int sampleSize,
    @JsonKey(name: 'priority_score') double? priorityScore,
    TopicTrend? trend,
    @JsonKey(name: 'trend_message') String? trendMessage,
  }) = _PerformanceTopic;

  factory PerformanceTopic.fromJson(Map<String, dynamic> json) =>
      _$PerformanceTopicFromJson(json);
}

/// [sections[].topics] di spec adalah `oneOf`: array PerformanceTopic
/// normal, ATAU `{locked: true}` (kalau access.full=false untuk section
/// itu) -- freezed/json_serializable tidak dukung oneOf/union JSON native.
///
/// PENTING (pelajaran dari percobaan pertama): kasih .fromJson body custom
/// di sini TIDAK CUKUP -- itu bikin freezed skip generate toJson() juga
/// untuk class ini (bukan cuma fromJson), lalu PerformanceSummary.toJson()
/// (yang delegasi normal) gagal compile karena butuh
/// PerformanceSection.toJson() yang tidak pernah ter-generate. Makanya
/// oneOf ini dibereskan SEBELUM masuk ke fromJson standar -- lihat
/// sanitizePerformanceSummaryJson di bawah -- persis pola yang sudah
/// dipakai untuk streak/ranking. PerformanceSection sendiri tetap delegate
/// biasa supaya fromJson DAN toJson dua-duanya ke-generate normal.
@freezed
class PerformanceSection with _$PerformanceSection {
  const factory PerformanceSection({
    @JsonKey(name: 'section_id') required int sectionId,
    required String code,
    required String name,
    // "passed" | "not_passed" -- lihat getter isPassed. Disimpan raw
    // String (bukan enum) supaya tidak nambah 1 enum lagi cuma untuk 2
    // nilai yang gampang dibaca lewat getter sederhana.
    required String status,
    @JsonKey(name: 'current_score') required double currentScore,
    @JsonKey(name: 'min_passing_score') int? minPassingScore,
    @JsonKey(name: 'gap_to_pass') int? gapToPass,
    @Default(<PerformanceTopic>[]) List<PerformanceTopic> topics,
    // Disuntik oleh sanitizePerformanceSummaryJson dari bentuk
    // topics:{locked:true} -- BUKAN key asli dari API (makanya prefix `_`).
    // true = section di luar akses user (BEDA dari topics kosong biasa,
    // yang berarti section accessible tapi memang belum ada data topik).
    @JsonKey(name: '_topics_locked') @Default(false) bool topicsLocked,
  }) = _PerformanceSection;

  const PerformanceSection._();

  factory PerformanceSection.fromJson(Map<String, dynamic> json) =>
      _$PerformanceSectionFromJson(json);

  bool get isPassed => status == 'passed';
}

@freezed
class TopRecommendation with _$TopRecommendation {
  const factory TopRecommendation({
    @JsonKey(name: 'topic_id') required int topicId,
    @JsonKey(name: 'topic_name') required String topicName,
    @JsonKey(name: 'section_code') required String sectionCode,
    // mis. "high_weight_low_score" -- belum ada kebutuhan UI beda per
    // reason, disimpan mentah buat sekarang.
    required String reason,
    required String message,
    @JsonKey(name: 'suggested_question_count') required int suggestedQuestionCount,
    @JsonKey(name: 'practice_link') required String practiceLink,
  }) = _TopRecommendation;

  factory TopRecommendation.fromJson(Map<String, dynamic> json) =>
      _$TopRecommendationFromJson(json);
}

/// [access.upgrade_cta] BEDA dari [PerformanceSummary.cta] top-level --
/// dua CTA dengan pemicu berbeda (lihat catatan di PerformanceSummary).
/// Reuse bentuk PerformanceCta ({message, action_link}) karena identik.
@freezed
class PerformanceAccess with _$PerformanceAccess {
  const factory PerformanceAccess({
    required bool full,
    @JsonKey(name: 'upgrade_cta') PerformanceCta? upgradeCta,
  }) = _PerformanceAccess;

  factory PerformanceAccess.fromJson(Map<String, dynamic> json) =>
      _$PerformanceAccessFromJson(json);
}

@freezed
class PerformanceSummary with _$PerformanceSummary {
  const factory PerformanceSummary({
    PerformanceProgram? program,
    required PerformanceState state,
    @Default(<PerformanceSection>[]) List<PerformanceSection> sections,
    @JsonKey(name: 'top_recommendations')
    @Default(<TopRecommendation>[])
    List<TopRecommendation> topRecommendations,
    required StreakInfo streak,
    RankingInfo? ranking,
    PerformanceAccess? access,
    // x-verified: source-code -- HANYA ada kalau state == noAttempts
    // (spec: "hanya ada kalau state=no_attempts"). CTA generik "ayo mulai
    // try-out pertamamu", BEDA TUJUAN dari access.upgradeCta (upsell
    // paket/subscription kalau access.full=false) -- JANGAN digabung,
    // keduanya bisa tampil di konteks yang sama sekali berbeda.
    PerformanceCta? cta,
  }) = _PerformanceSummary;

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) =>
      _$PerformanceSummaryFromJson(json);
}

/// [streak] dan [ranking] mentah dari backend ditandai `x-verified:
/// inferred` di OpenAPI spec -- bentuk field-nya DUGAAN, belum
/// dicocokkan ke source code backend. WAJIB dipanggil oleh pemanggil
/// (BerandaApiService) SEBELUM PerformanceSummary.fromJson:
///
///   final json = sanitizePerformanceSummaryJson(rawJson);
///   final summary = PerformanceSummary.fromJson(json);
///
/// CATATAN: sengaja TIDAK ditaruh di dalam factory PerformanceSummary.fromJson
/// itu sendiri -- freezed cuma men-generate `_$PerformanceSummaryFromJson`
/// di .g.dart kalau factory-nya persis delegasi (`=> _$XFromJson(json)`);
/// begitu body-nya diganti custom, fungsi itu tidak ter-generate sama
/// sekali (ini penyebab error "Method not found:
/// _$PerformanceSummaryFromJson" pada percobaan sebelumnya).
///
/// Fungsi ini JUGA membereskan `sections[].topics` (oneOf: array topik
/// normal ATAU `{locked:true}`) sebelum masuk ke fromJson standar --
/// percobaan pertama coba override PerformanceSection.fromJson langsung
/// buat oneOf ini, ternyata itu bikin freezed skip generate toJson() juga
/// untuk class itu (bukan cuma fromJson), lalu PerformanceSummary.toJson()
/// gagal compile karena butuh PerformanceSection.toJson() yang tidak
/// pernah ter-generate. Sanitasi di sini -- ubah {locked:true} jadi
/// topics:[] + suntik key sintetis `_topics_locked:true` -- menghindari
/// masalah itu sama sekali karena PerformanceSection tetap factory
/// delegate biasa.
Map<String, dynamic> sanitizePerformanceSummaryJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);

  final streakRaw = sanitized['streak'];
  if (streakRaw is! Map || streakRaw['count'] is! int) {
    sanitized['streak'] = {'count': 0, 'active_today': false};
  }

  final sectionsRaw = sanitized['sections'];
  if (sectionsRaw is List) {
    sanitized['sections'] = sectionsRaw.map((s) {
      if (s is! Map) return s;
      final section = Map<String, dynamic>.from(s);
      final topicsRaw = section['topics'];
      if (topicsRaw is Map && topicsRaw['locked'] == true) {
        section['topics'] = <dynamic>[];
        section['_topics_locked'] = true;
      }
      return section;
    }).toList();
  }

  final rankingRaw = sanitized['ranking'];
  if (rankingRaw != null &&
      (rankingRaw is! Map ||
          rankingRaw['rank'] is! int ||
          rankingRaw['total_participants'] is! int ||
          rankingRaw['percentile'] == null ||
          rankingRaw['exam_batch_id'] is! int)) {
    sanitized['ranking'] = null;
  }

  return sanitized;
}

// ==================== /my-subscription ====================
@freezed
class SubscriptionPlanRef with _$SubscriptionPlanRef {
  const factory SubscriptionPlanRef({
    int? id,
    String? name,
  }) = _SubscriptionPlanRef;

  factory SubscriptionPlanRef.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanRefFromJson(json);
}

@freezed
class SubscriptionStatus with _$SubscriptionStatus {
  const factory SubscriptionStatus({
    required int id,
    SubscriptionPlanRef? plan,
    required String status,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'end_date') String? endDate,
  }) = _SubscriptionStatus;

  const SubscriptionStatus._();

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionStatusFromJson(json);

  bool get isActive => status == 'active';
}

double _promoDiscountValueFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// ==================== /promos/active ====================
@freezed
class PromoBanner with _$PromoBanner {
  const factory PromoBanner({
    required int id,
    required String title,
    String? description,
    @JsonKey(name: 'discount_type') required String discountType,
    @JsonKey(
      name: 'discount_value',
      fromJson: _promoDiscountValueFromJson,
    )
    required double discountValue,
    required String code,
    @JsonKey(name: 'valid_until') String? validUntil,
  }) = _PromoBanner;

  const PromoBanner._();

  factory PromoBanner.fromJson(Map<String, dynamic> json) =>
      _$PromoBannerFromJson(json);

  String get discountLabel => discountType == 'percentage'
      ? '${discountValue.toStringAsFixed(0)}%'
      : 'Rp${discountValue.toStringAsFixed(0)}';
}

// ==================== Package -> tampilan Beranda ====================
@freezed
class RecommendedPackage with _$RecommendedPackage {
  const factory RecommendedPackage({
    required int id,
    required String name,
    required double price,
    double? discountPrice,
    String? bannerImageUrl,
    List<String>? features,
  }) = _RecommendedPackage;

  const RecommendedPackage._();

  static RecommendedPackage fromPackage(PackageModel package) => RecommendedPackage(
        id: package.id,
        name: package.name,
        price: package.price,
        discountPrice: package.discountPrice,
        bannerImageUrl: package.bannerImageUrl,
        features: package.features,
      );

  String? get discountLabel {
    if (discountPrice == null || price <= 0 || discountPrice! >= price) {
      return null;
    }
    final percent = (((price - discountPrice!) / price) * 100).round();
    return '$percent%';
  }
}

// ==================== Agregat layar Beranda ====================
@freezed
class BerandaRawData with _$BerandaRawData {
  const factory BerandaRawData({
    required List<RecommendedPackage> recommendedPackages,
    ContinueExamData? continueExam,
    required PerformanceSummary performance,
    SubscriptionStatus? subscription,
    required List<PromoBanner> promoBanners,
    required int unreadNotificationCount,
    // Cuma diisi kalau user BELUM punya subscription aktif -- lihat
    // BerandaRepository.getBerandaData(). Reuse SubscriptionPlanModel dari
    // modul subscription (GET /subscription-plans sudah ada providernya di
    // sana, bukan panggilan baru dari sisi API), dipakai buat kartu
    // "Upgrade ke Langganan" di Beranda. List kosong kalau subscription
    // sudah aktif (tidak perlu upsell) ATAU fetch plan gagal.
    @Default(<SubscriptionPlanModel>[]) List<SubscriptionPlanModel> subscriptionPlans,
  }) = _BerandaRawData;
}

@freezed
class BerandaData with _$BerandaData {
  const factory BerandaData({
    required String userName,
    ContinueExamData? continueExam,
    required bool hasActiveSubscription,
    String? subscriptionPackageName,
    required List<RecommendedPackage> recommendedPackages,
    required List<PromoBanner> promoBanners,
    required int streakDays,
    required double averageScore,
    required int rank,
    required int unreadNotificationCount,
    // Objek penuh (sections/topics/top_recommendations/access) -- dipakai
    // screen Analisis Performa supaya reuse cache Beranda, tidak perlu
    // panggilan GET /me/performance-summary kedua. streakDays/rank di atas
    // TETAP dipertahankan terpisah (bukan cuma performance.streak.count)
    // karena keduanya sudah dipakai widget Beranda yang ada -- mengubahnya
    // jadi getter turunan dari sini beresiko regresi di luar scope
    // pekerjaan ini.
    required PerformanceSummary performance,
    // Lihat catatan di BerandaRawData.subscriptionPlans -- kosong kalau
    // hasActiveSubscription true (tidak perlu tampilkan upsell).
    @Default(<SubscriptionPlanModel>[]) List<SubscriptionPlanModel> subscriptionPlans,
  }) = _BerandaData;
}
