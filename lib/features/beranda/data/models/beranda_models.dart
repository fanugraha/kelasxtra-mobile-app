// lib/features/beranda/data/models/beranda_models.dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../katalog/data/models/package_model.dart';

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
    required int remainingSeconds,
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

@freezed
class PerformanceSummary with _$PerformanceSummary {
  const factory PerformanceSummary({
    PerformanceProgram? program,
    required PerformanceState state,
    required StreakInfo streak,
    RankingInfo? ranking,
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
Map<String, dynamic> sanitizePerformanceSummaryJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);

  final streakRaw = sanitized['streak'];
  if (streakRaw is! Map || streakRaw['count'] is! int) {
    sanitized['streak'] = {'count': 0, 'active_today': false};
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
  }) = _BerandaData;
}
