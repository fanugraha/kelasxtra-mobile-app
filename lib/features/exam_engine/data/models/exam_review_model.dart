// lib/features/exam_engine/data/models/exam_review_model.dart
//
// Model GET /exam-attempts/{id}/review. Awalnya `x-verified: inferred`
// TANPA schema sama sekali di spec -- sekarang diverifikasi dari response
// asli (attempt #12, exam #1 "TO SKD 2026 - 10", 31 Jul 2026).
//
// Catatan penting dari data asli:
// - `is_correct` per soal TRI-STATE: true (benar) / false (salah, sudah
//   dijawab) / null (belum dijawab ATAU soal TKP yang memang tidak dinilai
//   benar-salah). JANGAN treat null sebagai false di UI.
// - Soal TKP (Tes Karakteristik Pribadi) TIDAK punya jawaban benar --
//   correct_option_id selalu null, semua options[].is_correct selalu
//   false, is_correct selalu null. TKP dinilai berbasis bobot skala,
//   bukan benar/salah, jadi UI tidak boleh menampilkan "kunci jawaban"
//   untuk kategori ini.
// - Soal reuse bentuk `category` yang identik dengan ExamQuestionCategory
//   di exam_attempt_model.dart (code+name) -- sengaja dipakai ulang di
//   sini, bukan didefinisikan dobel.
import 'package:freezed_annotation/freezed_annotation.dart';

import 'exam_attempt_model.dart';

part 'exam_review_model.freezed.dart';
part 'exam_review_model.g.dart';

@freezed
class ExamReviewSubTopic with _$ExamReviewSubTopic {
  const factory ExamReviewSubTopic({
    required int id,
    required String code,
    required String name,
  }) = _ExamReviewSubTopic;

  factory ExamReviewSubTopic.fromJson(Map<String, dynamic> json) =>
      _$ExamReviewSubTopicFromJson(json);
}

@freezed
class ExamReviewOption with _$ExamReviewOption {
  const factory ExamReviewOption({
    required int id,
    @JsonKey(name: 'option_text') required String optionText,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'is_correct') @Default(false) bool isCorrect,
  }) = _ExamReviewOption;

  factory ExamReviewOption.fromJson(Map<String, dynamic> json) =>
      _$ExamReviewOptionFromJson(json);
}

@freezed
class ExamReviewQuestion with _$ExamReviewQuestion {
  const factory ExamReviewQuestion({
    @JsonKey(name: 'question_id') required int questionId,
    @JsonKey(name: 'question_text') required String questionText,
    @JsonKey(name: 'media_type') String? mediaType,
    @JsonKey(name: 'media_url') String? mediaUrl,
    required ExamQuestionType type,
    required String topic,
    required ExamQuestionCategory category,
    @JsonKey(name: 'sub_topic') ExamReviewSubTopic? subTopic,
    String? explanation,
    @Default([]) List<ExamReviewOption> options,
    @JsonKey(name: 'selected_option_id') int? selectedOptionId,
    @JsonKey(name: 'essay_answer') String? essayAnswer,
    @JsonKey(name: 'correct_option_id') int? correctOptionId,
    // Tri-state -- lihat catatan panjang di atas. Nullable, JANGAN di-`??
    // false`.
    @JsonKey(name: 'is_correct') bool? isCorrect,
    @JsonKey(name: 'needs_manual_grading') @Default(false) bool needsManualGrading,
  }) = _ExamReviewQuestion;

  const ExamReviewQuestion._();

  factory ExamReviewQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamReviewQuestionFromJson(json);

  bool get wasAnswered => selectedOptionId != null || essayAnswer != null;

  /// TKP tidak punya kunci jawaban (correct_option_id selalu null) --
  /// dipakai UI untuk menyembunyikan highlight benar/salah pada opsi.
  bool get hasAnswerKey => correctOptionId != null;
}

@freezed
class ExamReviewModel with _$ExamReviewModel {
  const factory ExamReviewModel({
    @JsonKey(name: 'attempt_id') required int attemptId,
    @JsonKey(name: 'exam_title') required String examTitle,
    required double score,
    @JsonKey(name: 'correct_count') required int correctCount,
    @Default([]) List<ExamReviewQuestion> questions,
  }) = _ExamReviewModel;

  factory ExamReviewModel.fromJson(Map<String, dynamic> json) =>
      _$ExamReviewModelFromJson(json);
}
