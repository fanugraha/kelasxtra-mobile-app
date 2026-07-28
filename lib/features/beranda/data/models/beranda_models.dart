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
// Hanya field yang dipakai Continue Card di Beranda yang di-parse di sini
// (title, duration_minutes, in_progress_attempt_id). Endpoint aslinya juga
// punya attempts_count/first_attempt/latest_attempt/sections -- tambahkan
// kalau nanti ada layar lain (mis. halaman detail exam) yang butuh itu.
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

/// GET /exam-attempts/{attempt} -- cuma 2 field yang dipakai buat hitung
/// progress Continue Card. CATATAN: API tidak expose jumlah soal
/// terjawab, jadi ini estimasi progress berdasar WAKTU TERPAKAI
/// (1 - remaining_seconds / (duration_minutes*60)), bukan progress soal.
@freezed
class ExamAttemptProgress with _$ExamAttemptProgress {
  const factory ExamAttemptProgress({
    required int remainingSeconds,
    required int durationMinutes,
  }) = _ExamAttemptProgress;
}

/// Bentuk yang dipakai langsung oleh _ContinueCard di beranda_screen.dart.
/// Hasil GABUNGAN 3 panggilan (lihat BerandaRepository):
///   1. /my-exams/latest-attempted -> exam_id
///   2. /exams/{exam_id}/summary -> title, in_progress_attempt_id
///   3. /exam-attempts/{attempt_id} (kalau in_progress_attempt_id ada) -> progress
@freezed
class ContinueExamData with _$ContinueExamData {
  const factory ContinueExamData({
    required int examId,
    required String title,
    /// 0.0-1.0. Tetap 0.0 kalau tidak ada attempt in_progress (exam_id
    /// ini murni rekomendasi, belum pernah dikerjakan).
    required double progress,
    int? inProgressAttemptId,
  }) = _ContinueExamData;
}

// ==================== /me/performance-summary ====================
// CATATAN SCOPE: cuma field level-atas yang dipakai kartu Beranda (state,
// streak, ranking, cta). Breakdown per-section/topik (`sections`,
// `top_recommendations`, `access`) BELUM diparse -- kalau nanti ada layar
// "Peta Kekuatan" yang butuh itu, tambahkan model & field-nya di sini.

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

/// null kalau user belum pernah punya snapshot leaderboard untuk program ini
/// (RankingService::latestRanking() balikin null).
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

/// Hanya ada kalau state == no_attempts.
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

// ==================== /my-subscription ====================
// KONFIRMASI dari OpenAPI spec (kelasxtra-openapi.yaml) + response asli --
// bukan asumsi lagi. Bentuk: {"subscription": null | {id, plan, status,
// start_date, end_date, covered_program_ids}}. TIDAK ADA field is_active
// -- status aktif ditentukan dari field `status` (string, kemungkinan
// besar "active" berdasar konvensi Laravel, TAPI nilai enum lengkapnya
// belum dikonfirmasi dari akun yang benar-benar subscribe -- cek ulang
// begitu ada akun tes dengan subscription aktif).
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

  /// TODO: nilai enum `status` yang sebenarnya belum dikonfirmasi dari
  /// response asli (belum ada akun tes dengan subscription aktif).
  /// "active" adalah asumsi konvensi Laravel paling umum -- cek ulang
  /// begitu ada data nyata.
  bool get isActive => status == 'active';
}

/// Helper konversi field numerik yang di backend Laravel sering datang
/// sebagai STRING (decimal cast), bukan number JSON asli -- pola yang
/// sama juga dipakai PackageModel.price. Freezed/json_serializable tidak
/// otomatis convert String -> double, jadi wajib eksplisit di sini.
double _promoDiscountValueFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// ==================== /promos/active ====================
// KONFIRMASI dari OpenAPI spec + response asli. Field asli SANGAT beda
// dari asumsi awal -- tidak ada image_url/action_link sama sekali (itu
// murni karangan sebelum ada spec). Ini kode promo (discount_type,
// discount_value, code), bukan banner marketing gambar.
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

  /// Label singkat buat card carousel, mis. "20%" atau "Rp2.000".
  String get discountLabel => discountType == 'percentage'
      ? '${discountValue.toStringAsFixed(0)}%'
      : 'Rp${discountValue.toStringAsFixed(0)}';
}

// ==================== Package -> tampilan Beranda ====================

/// Bentuk Package yang dipakai card _RecommendedPackages di
/// beranda_screen.dart. Sudah termasuk features (dipakai untuk 1-2 bullet
/// singkat di card) -- kalau nanti perlu field lain, ambil dari
/// PackageModel penuh (lib/features/katalog/data/models/package_model.dart).
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

  /// Label diskon buat banner promo (mis. "20%"). Null kalau tidak ada
  /// discount_price, atau discount_price >= price (data tidak valid).
  String? get discountLabel {
    if (discountPrice == null || price <= 0 || discountPrice! >= price) {
      return null;
    }
    final percent = (((price - discountPrice!) / price) * 100).round();
    return '$percent%';
  }
}

// ==================== Agregat layar Beranda ====================

/// Output BerandaRepository -- murni hasil gabungan API, BELUM ada
/// userName (itu dari authNotifierProvider, bukan tanggung jawab
/// repository data/) dan BELUM flat seperti yang widget minta.
/// BerandaNotifier di presentation/ yang meratakan ini jadi [BerandaData].
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

/// Bentuk FINAL yang dikonsumsi beranda_screen.dart lewat
/// berandaNotifierProvider. Field level-atas & flat -- ini kontrak dengan
/// widget yang sudah ada, jangan diubah tanpa update beranda_screen.dart
/// juga.
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
    // TODO: /me/performance-summary tidak punya field skor rata-rata
    // tunggal (cuma breakdown per-section/topik) -- belum ada sumber data
    // yang valid. Selalu 0 (UI sudah handle: tampilkan '-') sampai
    // didefinisikan cara hitungnya / backend menyediakan field-nya.
    required double averageScore,
    required int rank,
    required int unreadNotificationCount,
  }) = _BerandaData;
}
