// lib/features/exam_engine/data/models/exam_summary_model.dart
//
// Model untuk GET /exams/{exam}/summary (x-verified: source-code, field &
// tipe cocok schema di kelasxtra-openapi.yaml -- sudah dicek juga terhadap
// response asli di log `flutter run` tanggal 29 Jul 2026, cocok persis)
// dan GET /packages/{package}/exams (x-verified: inferred -- lihat catatan
// di [ExamListItemModel] sebelum dipakai untuk hal kritikal).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_summary_model.freezed.dart';
part 'exam_summary_model.g.dart';

@freezed
class ExamSectionInfo with _$ExamSectionInfo {
  const factory ExamSectionInfo({
    required String code,
    required String name,
    @JsonKey(name: 'min_passing_score') int? minPassingScore,
  }) = _ExamSectionInfo;

  factory ExamSectionInfo.fromJson(Map<String, dynamic> json) =>
      _$ExamSectionInfoFromJson(json);
}

@freezed
class ExamInfo with _$ExamInfo {
  const factory ExamInfo({
    required int id,
    required String title,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    @Default([]) List<ExamSectionInfo> sections,
  }) = _ExamInfo;

  factory ExamInfo.fromJson(Map<String, dynamic> json) => _$ExamInfoFromJson(json);
}

@freezed
class ExamAttemptSectionScore with _$ExamAttemptSectionScore {
  const factory ExamAttemptSectionScore({
    required String code,
    required String name,
    @JsonKey(name: 'raw_score') required double rawScore,
    @JsonKey(name: 'min_passing_score') int? minPassingScore,
    // null = section ini tidak punya threshold kelulusan sendiri (mis. TKP
    // di TWK/TIU/TKP -- lihat contoh response, passed_threshold-nya null).
    @JsonKey(name: 'passed_threshold') bool? passedThreshold,
  }) = _ExamAttemptSectionScore;

  factory ExamAttemptSectionScore.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptSectionScoreFromJson(json);
}

@freezed
class ExamBankRef with _$ExamBankRef {
  const factory ExamBankRef({
    required int id,
    required String title,
  }) = _ExamBankRef;

  factory ExamBankRef.fromJson(Map<String, dynamic> json) => _$ExamBankRefFromJson(json);
}

@freezed
class ExamAttemptSummary with _$ExamAttemptSummary {
  const factory ExamAttemptSummary({
    @JsonKey(name: 'attempt_id') required int attemptId,
    @JsonKey(name: 'finished_at') required DateTime finishedAt,
    required double score,
    @JsonKey(name: 'correct_count') required int correctCount,
    required bool passed,
    @Default([]) List<ExamAttemptSectionScore> sections,
    ExamBankRef? bank,
  }) = _ExamAttemptSummary;

  factory ExamAttemptSummary.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptSummaryFromJson(json);
}

@freezed
class ExamSummaryModel with _$ExamSummaryModel {
  const factory ExamSummaryModel({
    required ExamInfo exam,
    @JsonKey(name: 'in_progress_attempt_id') int? inProgressAttemptId,
    @JsonKey(name: 'attempts_count') required int attemptsCount,
    @JsonKey(name: 'first_attempt') ExamAttemptSummary? firstAttempt,
    @JsonKey(name: 'latest_attempt') ExamAttemptSummary? latestAttempt,
  }) = _ExamSummaryModel;

  const ExamSummaryModel._();

  factory ExamSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$ExamSummaryModelFromJson(json);

  bool get hasInProgressAttempt => inProgressAttemptId != null;
  bool get hasBeenAttempted => attemptsCount > 0;
}

/// GET /packages/{package}/exams -- ditandai `x-verified: inferred` di
/// spec, BELUM PERNAH dipanggil nyata. Field di bawah cuma tebakan
/// berdasarkan bentuk [ExamInfo] yang sudah terverifikasi (asumsi Laravel
/// memakai ExamResource yang sama di kedua endpoint) -- SEMUA field selain
/// [id] nullable/berdefault supaya parsing tidak crash kalau tebakannya
/// meleset, tapi JANGAN percaya penuh sebelum di-curl manual 1x dan
/// dicocokkan (sama seperti catatan review Fase 5).
@freezed
class ExamListItemModel with _$ExamListItemModel {
  const factory ExamListItemModel({
    required int id,
    String? title,
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    @JsonKey(name: 'in_progress_attempt_id') int? inProgressAttemptId,
    @JsonKey(name: 'attempts_count') int? attemptsCount,
  }) = _ExamListItemModel;

  const ExamListItemModel._();

  factory ExamListItemModel.fromJson(Map<String, dynamic> json) =>
      _$ExamListItemModelFromJson(json);

  bool get hasInProgressAttempt => inProgressAttemptId != null;
}
