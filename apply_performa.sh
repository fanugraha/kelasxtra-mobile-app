cat > lib/features/beranda/data/models/beranda_models.dart << 'EOF_MODELS'
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
/// itu) -- freezed/json_serializable tidak dukung oneOf/union JSON native,
/// jadi PerformanceSection.fromJson custom (bukan delegasi ke
/// _$PerformanceSectionFromJson -- makanya TIDAK di-generate freezed sama
/// sekali untuk method ini, konsisten dengan pola sanitizePerformanceSummaryJson
/// di bawah).
@freezed
class PerformanceSection with _$PerformanceSection {
  const factory PerformanceSection({
    @JsonKey(name: 'section_id') required int sectionId,
    required String code,
    required String name,
    // "passed" | "not_passed" -- lihat getter isPassed. Disimpan raw
    // String (bukan enum) karena fromJson section ini sudah custom (oneOf
    // topics di bawah), menambah 1 enum lagi cuma nambah boilerplate parse
    // manual tanpa manfaat nyata dibanding getter sederhana.
    required String status,
    @JsonKey(name: 'current_score') required double currentScore,
    @JsonKey(name: 'min_passing_score') int? minPassingScore,
    @JsonKey(name: 'gap_to_pass') int? gapToPass,
    @Default(<PerformanceTopic>[]) List<PerformanceTopic> topics,
    // true kalau topics di response ini bentuknya {locked:true} (section
    // di luar akses user) -- BEDA dari topics kosong (section accessible
    // tapi memang belum ada data topik sama sekali).
    @Default(false) bool topicsLocked,
  }) = _PerformanceSection;

  const PerformanceSection._();

  factory PerformanceSection.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'];
    var topics = const <PerformanceTopic>[];
    var locked = false;

    if (rawTopics is List) {
      topics = rawTopics
          .map((e) => PerformanceTopic.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (rawTopics is Map && rawTopics['locked'] == true) {
      locked = true;
    }

    return PerformanceSection(
      sectionId: json['section_id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      currentScore: (json['current_score'] as num).toDouble(),
      minPassingScore: json['min_passing_score'] as int?,
      gapToPass: json['gap_to_pass'] as int?,
      topics: topics,
      topicsLocked: locked,
    );
  }

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
    // Objek penuh (sections/topics/top_recommendations/access) -- dipakai
    // screen Analisis Performa supaya reuse cache Beranda, tidak perlu
    // panggilan GET /me/performance-summary kedua. streakDays/rank di atas
    // TETAP dipertahankan terpisah (bukan cuma performance.streak.count)
    // karena keduanya sudah dipakai widget Beranda yang ada -- mengubahnya
    // jadi getter turunan dari sini beresiko regresi di luar scope
    // pekerjaan ini.
    required PerformanceSummary performance,
  }) = _BerandaData;
}
EOF_MODELS

cat > lib/features/beranda/presentation/providers/beranda_provider.dart << 'EOF_PROVIDER'
// lib/features/beranda/presentation/providers/beranda_provider.dart
//
// PENTING: beranda_screen.dart cuma import file ini (bukan
// data/models/beranda_models.dart langsung), jadi model-model yang
// dipakai widget (ContinueExamData, RecommendedPackage, PromoBanner) di-
// export ulang di bawah supaya tetap terlihat dari satu import itu.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/beranda_repository.dart';
import '../../data/models/beranda_models.dart';

export '../../data/models/beranda_models.dart';

part 'beranda_provider.g.dart';

@riverpod
class BerandaNotifier extends _$BerandaNotifier {
  @override
  Future<BerandaData> build() async {
    final raw = await ref.watch(berandaRepositoryProvider).getBerandaData();

    final userName = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (user) => user.name,
          orElse: () => '',
        );

    return BerandaData(
      userName: userName,
      continueExam: raw.continueExam,
      hasActiveSubscription: raw.subscription?.isActive ?? false,
      subscriptionPackageName: raw.subscription?.plan?.name,
      recommendedPackages: raw.recommendedPackages,
      promoBanners: raw.promoBanners,
      streakDays: raw.performance.streak.count,
      // TODO: lihat catatan TODO di model BerandaData -- belum ada sumber
      // data valid untuk skor rata-rata tunggal.
      averageScore: 0,
      rank: raw.performance.ranking?.rank ?? 0,
      unreadNotificationCount: raw.unreadNotificationCount,
      performance: raw.performance,
    );
  }

  /// Dipanggil dari pull-to-refresh di layar Beranda.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
EOF_PROVIDER

cat > lib/features/beranda/data/beranda_api_service.dart << 'EOF_APISERVICE'
// lib/features/beranda/data/beranda_api_service.dart
//
// Panggilan HTTP mentah untuk Beranda. Tidak ada logic gabungan di sini --
// itu tanggung jawab BerandaRepository. Service ini murni mapping
// request/response per endpoint, supaya gampang di-mock waktu testing.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'models/beranda_models.dart';

part 'beranda_api_service.g.dart';

class BerandaApiService {
  BerandaApiService(this._dio);

  final Dio _dio;

  /// GET /packages/recommended
  Future<RecommendedPackagesResponse> getRecommendedPackages() async {
    final response = await _dio.get('/packages/recommended');
    return RecommendedPackagesResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// GET /my-exams/latest-attempted
  ///
  /// CATATAN PENTING: nama endpoint ini menyesatkan. Kalau user belum
  /// pernah attempt exam (di luar leaderboard batch), backend fallback ke
  /// exam tryout pertama yang boleh diakses user -- lihat
  /// ExamController::latestAttemptedExam() di backend. Jadi exam_id di sini
  /// TIDAK selalu berarti "sedang/pernah dikerjakan user". Attempt yang
  /// terikat exam_batch_id (leaderboard event) juga sengaja diexclude oleh
  /// backend dari pencarian "terakhir dikerjakan".
  ///
  /// Balikan `null` kalau memang tidak ada exam yang bisa direkomendasikan
  /// sama sekali (user belum punya akses ke exam manapun).
  Future<int?> getLatestAttemptedExamId() async {
    final response = await _dio.get('/my-exams/latest-attempted');
    final data = response.data as Map<String, dynamic>;
    return data['exam_id'] as int?;
  }

  /// GET /exams/{examId}/summary
  ///
  /// Dipakai buat lengkapi Continue Card: kasih `title` (exam_id doang
  /// dari latest-attempted tidak cukup buat ditampilkan ke user) dan
  /// `in_progress_attempt_id` (penentu tombol "Lanjutkan" vs "Mulai").
  Future<ExamSummaryResponse> getExamSummary(int examId) async {
    final response = await _dio.get('/exams/$examId/summary');
    return ExamSummaryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exam-attempts/{attemptId}
  ///
  /// Dipanggil cuma kalau /exams/{id}/summary balikin
  /// in_progress_attempt_id != null. Cuma ambil 2 field (remaining_seconds,
  /// duration_minutes) buat hitung progress -- tidak parse `questions`/
  /// `question_order` karena tidak dipakai di Beranda (itu buat layar
  /// exam_engine, konteks beda).
  Future<ExamAttemptProgress> getExamAttemptProgress(int attemptId) async {
    final response = await _dio.get('/exam-attempts/$attemptId');
    final data = response.data as Map<String, dynamic>;
    return ExamAttemptProgress(
      remainingSeconds: (data['remaining_seconds'] as num).toDouble(),
      durationMinutes: data['duration_minutes'] as int,
    );
  }

  /// GET /me/performance-summary
  ///
  /// [programId] SENGAJA wajib dikirim eksplisit oleh caller -- JANGAN
  /// andalkan default backend (`user.preferred_program_id`). Kolom itu
  /// tech debt yang belum pernah diisi untuk user manapun sejauh ini, jadi
  /// kalau program_id tidak dikirim, response bisa balik `no_attempts`
  /// padahal user sebenarnya sudah banyak mengerjakan tryout.
  Future<PerformanceSummary> getPerformanceSummary({int? programId}) async {
    final response = await _dio.get(
      '/me/performance-summary',
      queryParameters: {
        if (programId != null) 'program_id': programId,
      },
    );
    return PerformanceSummary.fromJson(sanitizePerformanceSummaryJson(response.data as Map<String, dynamic>));
  }

  /// GET /my-subscription
  ///
  /// KONFIRMASI dari OpenAPI spec: body dibungkus {"subscription": ...},
  /// null kalau user belum pernah subscribe. Return type nullable
  /// (bukan sentinel .none) karena bentuk field aslinya (id, plan,
  /// status, start_date, end_date) tidak punya representasi "kosong".
  Future<SubscriptionStatus?> getMySubscription() async {
    final response = await _dio.get('/my-subscription');
    final data = response.data as Map<String, dynamic>;
    final subscriptionJson = data['subscription'] as Map<String, dynamic>?;
    if (subscriptionJson == null) return null;
    return SubscriptionStatus.fromJson(subscriptionJson);
  }

  /// GET /promos/active
  ///
  /// KONFIRMASI dari OpenAPI spec: response array polos, sesuai dugaan
  /// awal -- tidak perlu diubah.
  Future<List<PromoBanner>> getActivePromos() async {
    final response = await _dio.get('/promos/active');
    final data = response.data as List<dynamic>;
    return data
        .map((json) => PromoBanner.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /notifications/unread-count
  ///
  /// KONFIRMASI dari OpenAPI spec + response asli: key-nya `count`,
  /// bukan `unread_count` (asumsi awal salah -- badge notifikasi di
  /// header selalu 0 sebelum fix ini, walau backend punya data).
  Future<int> getUnreadNotificationCount() async {
    final response = await _dio.get('/notifications/unread-count');
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }
}

@Riverpod(keepAlive: true)
BerandaApiService berandaApiService(BerandaApiServiceRef ref) {
  return BerandaApiService(ref.watch(dioProvider));
}
EOF_APISERVICE

cat > lib/features/beranda/presentation/screens/analisis_performa_screen.dart << 'EOF_ANALISIS'
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
      // di _NoAttemptsState) -- sementara diarahkan ke Paket Saya. TODO:
      // ganti jadi navigasi langsung ke Latihan Fokus per-topik begitu
      // Fase 6 (wiring Latihan) selesai dibangun.
      onTap: () => context.push('/paket-saya'),
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
EOF_ANALISIS

cat > lib/core/router/app_router.dart << 'EOF_ROUTER'
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
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';

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
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
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
EOF_ROUTER

cat > lib/features/beranda/presentation/screens/beranda_screen.dart << 'EOF_BERANDA'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/beranda_provider.dart';

class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: berandaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            onRetry: () => ref.read(berandaNotifierProvider.notifier).refresh(),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.read(berandaNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _HeaderRow(
                  userName: data.userName,
                  streakDays: data.streakDays,
                  hasActiveSubscription: data.hasActiveSubscription,
                  subscriptionPackageName: data.subscriptionPackageName,
                  unreadNotificationCount: data.unreadNotificationCount,
                ),
                const SizedBox(height: 24),
                _ContinueCard(exam: data.continueExam),
                if (data.promoBanners.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _PromoCarousel(banners: data.promoBanners),
                ],
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Latihan & Try Out'),
                const SizedBox(height: 12),
                const _PracticeGrid(),
                if (data.recommendedPackages.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Rekomendasi Paket'),
                  const SizedBox(height: 12),
                  _RecommendedPackages(packages: data.recommendedPackages),
                ],
                const SizedBox(height: 28),
                _StatsRow(averageScore: data.averageScore, rank: data.rank),
                const SizedBox(height: 20),
                _LeaderboardPreview(rank: data.rank),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({
    required this.userName,
    required this.streakDays,
    required this.hasActiveSubscription,
    required this.subscriptionPackageName,
    required this.unreadNotificationCount,
  });

  final String userName;
  final int streakDays;
  final bool hasActiveSubscription;
  final String? subscriptionPackageName;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brand500,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Halo,',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                  ),
                  if (hasActiveSubscription) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subscriptionPackageName ?? 'Premium',
                        style: const TextStyle(
                          color: AppColors.gold600,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (streakDays > 0) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, color: AppColors.danger600, size: 15),
                    const SizedBox(width: 2),
                    Text(
                      '$streakDays',
                      style: const TextStyle(
                        color: AppColors.danger600,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_outlined, color: AppColors.neutral600),
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.danger600,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.exam});
  final ContinueExamData? exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasExam = exam != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasExam ? Icons.play_circle_outline : Icons.bolt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasExam ? 'Lanjutkan Belajar' : 'Mulai Belajar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasExam ? exam!.title : 'Belum ada latihan hari ini',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasExam) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: exam!.progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(exam!.progress * 100).round()}% selesai',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // hasExam -> examId dari ContinueExamData sudah cukup untuk
              // masuk ke screen ringkasan exam (Fase 2), yang lalu push ke
              // exam-taking UI (Fase 3) begitu attempt dibuat/di-resume.
              // !hasExam -> belum ada exam untuk dilanjutkan sama sekali,
              // tetap arahkan ke tab Latihan seperti sebelumnya.
              onPressed: () {
                if (hasExam) {
                  context.push('/exams/${exam!.examId}/summary');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur ini segera hadir. Sementara, cek Latihan.')),
                  );
                  ref.read(selectedTabIndexProvider.notifier).state = 1;
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.brand700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(hasExam ? 'Lanjutkan' : 'Cari Latihan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carousel promo dari /promos/active. Ganti posisi banner upsell lama --
/// satu CTA utama saja sesuai prinsip yang disepakati (bukan tumpuk-tumpuk
/// promo + banner subscription sekaligus). Status subscription sekarang
/// cukup lewat badge kecil di header (_HeaderRow), bukan banner terpisah.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.banners});
  final List<PromoBanner> banners;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold600.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold600.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gold600.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.local_offer_outlined, color: AppColors.gold600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  banner.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.neutral900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.danger50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  banner.discountLabel,
                                  style: const TextStyle(
                                    color: AppColors.danger600,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kode: ${banner.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gold600,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.neutral400),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand500 : AppColors.neutral200,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.neutral900,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Grid 2x2 akses cepat. 3 item pertama pindah ke tab Latihan (index 1 di
/// AppShell) -- LatihanScreen saat ini masih placeholder ("segera hadir"),
/// jadi semua 3 akan mendarat di tempat yang sama untuk saat ini. Itu
/// bukan dead button (tab-nya nyata & merespons), cuma isinya belum
/// didesain -- akan otomatis benar begitu LatihanScreen dibangun dengan
/// section internal.
///
/// "Analisis Performa" sekarang push ke AnalisisPerformaScreen (konsumsi
/// PerformanceSummary penuh dari BerandaData.performance -- reuse cache
/// Beranda, tidak ada request tambahan).
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  static const _items = [
    (icon: Icons.topic_outlined, title: 'Latihan Soal per Topik', subtitle: 'Susun roadmap topik'),
    (icon: Icons.center_focus_strong_outlined, title: 'Latihan Fokus', subtitle: 'Perkuat kelemahanmu'),
    (icon: Icons.timer_outlined, title: 'Tryout', subtitle: 'Simulasi CAT penuh'),
    (icon: Icons.insights_outlined, title: 'Analisis Performa', subtitle: 'Lihat progres belajarmu'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: _items.map((item) {
        final isPerformance = item.title == 'Analisis Performa';
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isPerformance) {
              context.push('/analisis-performa');
            } else {
              ref.read(selectedTabIndexProvider.notifier).state = 1;
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.brand500, size: 22),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Format angka jadi "Rp20.000" (titik sebagai pemisah ribuan, tanpa
/// desimal -- harga selalu bulat rupiah di sini).
String _formatRupiah(double value) {
  final digits = value.round().toString().split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && i % 3 == 0) grouped.add('.');
    grouped.add(digits[i]);
  }
  return 'Rp${grouped.reversed.join()}';
}

/// Bentuk pita diskon bergaya e-commerce (flag/notch di sisi kanan) --
/// dipakai di pojok kiri-atas gambar card paket, mirip badge "-50%" di
/// Shopee/Tokopedia.
class _DiscountRibbon extends StatelessWidget {
  const _DiscountRibbon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        color: AppColors.danger600,
        padding: const EdgeInsets.only(left: 8, right: 12, top: 4, bottom: 4),
        child: Text(
          '-$label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final notch = 7.0;
    return Path()
      ..lineTo(0, size.height)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Chip kecil hijau bergaya "Gratis Ongkir"-nya Shopee -- dipakai buat
/// menonjolkan 1 fitur unggulan paket di card.
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success600.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.success600.withOpacity(0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.success600,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Section baru -- recommendedPackages sudah lama di-fetch tapi cuma
/// dipakai buat hitung discountLabel di banner lama. Sekarang ditampilkan
/// sebagai card gaya marketplace (Shopee-like): gambar persegi dengan
/// pita diskon, harga besar + harga asli dicoret + chip persen, dan chip
/// fitur unggulan.
class _RecommendedPackages extends StatelessWidget {
  const _RecommendedPackages({required this.packages});
  final List<RecommendedPackage> packages;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final package = packages[index];
          final hasDiscount = package.discountLabel != null;
          final features = package.features ?? const <String>[];

          return Container(
            width: 168,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: package.bannerImageUrl != null
                          ? Image.network(
                              package.bannerImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: AppColors.neutral100),
                            )
                          : Container(
                              color: AppColors.neutral100,
                              alignment: Alignment.center,
                              child: const Icon(Icons.school_outlined, color: AppColors.neutral400),
                            ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 0,
                        child: _DiscountRibbon(label: package.discountLabel!),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutral900,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatRupiah(package.discountPrice ?? package.price),
                        style: const TextStyle(
                          color: AppColors.danger600,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatRupiah(package.price),
                              style: const TextStyle(
                                color: AppColors.neutral400,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.danger50,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: AppColors.danger600.withOpacity(0.4)),
                              ),
                              child: Text(
                                package.discountLabel!,
                                style: const TextStyle(
                                  color: AppColors.danger600,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _FeatureChip(label: features.first),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Disederhanakan jadi 2 kolom -- Streak pindah ke header (mini, gaya
/// Duolingo), jadi tidak perlu diulang di sini.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.averageScore, required this.rank});

  final double averageScore;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.insights_outlined,
            iconColor: AppColors.success600,
            label: 'Skor Rata-rata',
            value: averageScore > 0 ? averageScore.toStringAsFixed(0) : '-',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_outlined,
            iconColor: AppColors.gold600,
            label: 'Peringkat',
            value: rank > 0 ? '#$rank' : '-',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPreview extends ConsumerWidget {
  const _LeaderboardPreview({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sebelumnya kartu ini punya ikon chevron (menyiratkan bisa di-tap)
    // tapi tidak ada onTap sama sekali -- ditambahkan supaya benar-benar
    // membawa user ke tab Peringkat, bukan dead UI.
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 2,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold600.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.leaderboard_outlined, color: AppColors.gold600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank > 0 ? 'Kamu peringkat #$rank minggu ini' : 'Belum masuk peringkat',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Lihat papan peringkat lengkap',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.neutral400),
        ],
      ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
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
            const Text(
              'Gagal memuat beranda',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
EOF_BERANDA

echo 'PerformanceSummary lengkap + Analisis Performa screen + fix remaining_seconds bug diterapkan.'
