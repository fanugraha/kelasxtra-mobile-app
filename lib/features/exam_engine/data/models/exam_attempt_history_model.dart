// lib/features/exam_engine/data/models/exam_attempt_history_model.dart
//
// Model untuk GET /exams/{exam}/attempts -- x-verified: source-code,
// dicocokkan langsung ke ExamController::attempts() di kelasxtra-backend
// (openapi.yaml masih `x-verified: inferred` untuk endpoint ini).
//
// BEDA dari GET /exams/{exam}/summary (lihat [ExamSummaryModel]):
// - summary() cuma balikin first_attempt & latest_attempt (2 attempt saja).
// - attempts() balikin SEMUA attempt yang sudah selesai (status submitted/
//   auto_submitted/graded), diurutkan started_at ASC, masing-masing sudah
//   dilengkapi attempt_number (1-based, urutan pengerjaan) dan
//   correct_count PER SECTION (summary() tidak punya ini di section-nya).
// - Filter status di backend TIDAK termasuk in_progress -- endpoint ini
//   tidak pernah mengirim attempt yang belum selesai, jadi finished_at
//   dan started_at selalu ada.
// - `exam` di sini cuma subset {id, title, passing_score} -- BUKAN
//   [ExamInfo] penuh (tidak ada duration_minutes/sections/is_free_preview).
import 'package:freezed_annotation/freezed_annotation.dart';

import 'exam_summary_model.dart';

part 'exam_attempt_history_model.freezed.dart';
part 'exam_attempt_history_model.g.dart';

@freezed
class ExamAttemptHistorySectionScore with _$ExamAttemptHistorySectionScore {
  const factory ExamAttemptHistorySectionScore({
    required String code,
    required String name,
    @JsonKey(name: 'raw_score') required double rawScore,
    @JsonKey(name: 'correct_count') @Default(0) int correctCount,
    @JsonKey(name: 'min_passing_score') int? minPassingScore,
    // null = section ini tidak punya threshold kelulusan sendiri -- pola
    // sama seperti ExamAttemptSectionScore.passedThreshold di summary.
    @JsonKey(name: 'passed_threshold') bool? passedThreshold,
  }) = _ExamAttemptHistorySectionScore;

  factory ExamAttemptHistorySectionScore.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptHistorySectionScoreFromJson(json);
}

@freezed
class ExamAttemptHistoryItem with _$ExamAttemptHistoryItem {
  const factory ExamAttemptHistoryItem({
    @JsonKey(name: 'attempt_id') required int attemptId,
    @JsonKey(name: 'attempt_number') required int attemptNumber,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'finished_at') required DateTime finishedAt,
    required double score,
    @JsonKey(name: 'correct_count') required int correctCount,
    @Default([]) List<ExamAttemptHistorySectionScore> sections,
    // null = exam ini tidak punya aturan kelulusan sama sekali (lihat
    // Exam::isAttemptPassed) -- pola sama seperti ExamAttemptSummary.passed.
    bool? passed,
    // Terisi hanya untuk try-out multi-bank (mis. TWK/TIU/TKP terpisah
    // attempt) -- null untuk exam single-bank/latihan topik biasa.
    ExamBankRef? bank,
  }) = _ExamAttemptHistoryItem;

  factory ExamAttemptHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptHistoryItemFromJson(json);
}

@freezed
class ExamAttemptHistoryExamInfo with _$ExamAttemptHistoryExamInfo {
  const factory ExamAttemptHistoryExamInfo({
    required int id,
    required String title,
    @JsonKey(name: 'passing_score') int? passingScore,
  }) = _ExamAttemptHistoryExamInfo;

  factory ExamAttemptHistoryExamInfo.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptHistoryExamInfoFromJson(json);
}

@freezed
class ExamAttemptHistoryResponse with _$ExamAttemptHistoryResponse {
  const factory ExamAttemptHistoryResponse({
    required ExamAttemptHistoryExamInfo exam,
    @Default([]) List<ExamAttemptHistoryItem> attempts,
  }) = _ExamAttemptHistoryResponse;

  const ExamAttemptHistoryResponse._();

  factory ExamAttemptHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptHistoryResponseFromJson(json);

  bool get isEmpty => attempts.isEmpty;
}
