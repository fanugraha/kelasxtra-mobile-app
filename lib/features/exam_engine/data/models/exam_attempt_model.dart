// lib/features/exam_engine/data/models/exam_attempt_model.dart
//
// Model ExamAttempt -- bentuk response POST /exams/start, GET
// /exam-attempts/{id}, POST .../finish. Field & tipe cocok dengan schema
// ExamAttempt di kelasxtra-openapi.yaml (x-verified: source-code, dari
// ExamAttemptResource.php).
//
// PENTING: `question_order` dan `questions` HANYA muncul dari server kalau
// status = in_progress; `current_section` HANYA ada kalau in_progress DAN
// uses_section_timers=true. Ketiganya nullable di sini -- JANGAN diakses
// tanpa guard status di provider/UI (lihat catatan di area kelasxtra).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_attempt_model.freezed.dart';
part 'exam_attempt_model.g.dart';

enum ExamAttemptStatus {
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('submitted')
  submitted,
  @JsonValue('auto_submitted')
  autoSubmitted,
  @JsonValue('graded')
  graded,
}

enum ExamQuestionType {
  @JsonValue('pg')
  pg,
  @JsonValue('essay')
  essay,
}

@freezed
class ExamCurrentSection with _$ExamCurrentSection {
  const factory ExamCurrentSection({
    required int id,
    required String code,
    required String name,
    required int order,
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    // Belum ada data asli untuk field ini (uses_section_timers=false pada
    // exam yang sudah ditest) -- dibuat double untuk konsisten dengan
    // remaining_seconds di level attempt yang terbukti desimal. VERIFIKASI
    // ULANG begitu ada exam dengan uses_section_timers=true.
    @JsonKey(name: 'remaining_seconds') double? remainingSeconds,
  }) = _ExamCurrentSection;

  factory ExamCurrentSection.fromJson(Map<String, dynamic> json) =>
      _$ExamCurrentSectionFromJson(json);
}

@freezed
class ExamQuestionOrderOption with _$ExamQuestionOrderOption {
  const factory ExamQuestionOrderOption({
    @JsonKey(name: 'question_id') required int questionId,
    @JsonKey(name: 'option_ids') required List<int> optionIds,
  }) = _ExamQuestionOrderOption;

  factory ExamQuestionOrderOption.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionOrderOptionFromJson(json);
}

/// Urutan tampil soal & opsi HASIL PENGACAKAN SERVER untuk attempt ini --
/// dipakai untuk merender `questions`/`options` sesuai urutan yang sama
/// persis dengan yang dilihat user (server yang menentukan random seed,
/// bukan client).
@freezed
class ExamQuestionOrder with _$ExamQuestionOrder {
  const factory ExamQuestionOrder({
    required List<int> questions,
    @Default([]) List<ExamQuestionOrderOption> options,
  }) = _ExamQuestionOrder;

  factory ExamQuestionOrder.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionOrderFromJson(json);
}

@freezed
class ExamQuestionCategory with _$ExamQuestionCategory {
  const factory ExamQuestionCategory({
    required String code,
    required String name,
  }) = _ExamQuestionCategory;

  factory ExamQuestionCategory.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionCategoryFromJson(json);
}

@freezed
class ExamOption with _$ExamOption {
  const factory ExamOption({
    required int id,
    @JsonKey(name: 'option_text') required String optionText,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _ExamOption;

  factory ExamOption.fromJson(Map<String, dynamic> json) =>
      _$ExamOptionFromJson(json);
}

@freezed
class ExamQuestion with _$ExamQuestion {
  const factory ExamQuestion({
    required int id,
    @JsonKey(name: 'question_text') required String questionText,
    @JsonKey(name: 'media_type') String? mediaType,
    @JsonKey(name: 'media_url') String? mediaUrl,
    required ExamQuestionType type,
    ExamQuestionCategory? category,
    @Default([]) List<ExamOption> options,
  }) = _ExamQuestion;

  const ExamQuestion._();

  factory ExamQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionFromJson(json);

  bool get isEssay => type == ExamQuestionType.essay;
}

/// Jawaban yang sudah tersimpan di server untuk attempt ini -- dipakai
/// untuk resume (mis. app di-kill lalu dibuka lagi selagi attempt masih
/// in_progress). x-verified: INFERRED, bukan source-code -- response
/// `answers: []` selalu kosong sejauh ini karena testing selalu attempt
/// baru tanpa jawaban tersimpan. Bentuk field di bawah adalah tebakan
/// paling masuk akal berdasar payload POST .../answer (question_id +
/// selected_option_id/essay_answer). VERIFIKASI ULANG begitu ada attempt
/// in_progress yang sudah punya jawaban lalu di-GET ulang.
@freezed
class ExamAnsweredQuestion with _$ExamAnsweredQuestion {
  const factory ExamAnsweredQuestion({
    @JsonKey(name: 'question_id') required int questionId,
    @JsonKey(name: 'selected_option_id') int? selectedOptionId,
    @JsonKey(name: 'essay_answer') String? essayAnswer,
  }) = _ExamAnsweredQuestion;

  factory ExamAnsweredQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamAnsweredQuestionFromJson(json);
}

@freezed
class ExamAttemptModel with _$ExamAttemptModel {
  const factory ExamAttemptModel({
    required int id,
    @JsonKey(name: 'exam_id') required int examId,
    @JsonKey(name: 'exam_batch_id') int? examBatchId,
    @JsonKey(name: 'bank_id') int? bankId,
    required ExamAttemptStatus status,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'finished_at') DateTime? finishedAt,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    // Desimal di API asli (mis. 5999.053557), BUKAN integer -- "0 kalau
    // status bukan in_progress" (spec) -- jangan dipakai untuk hitung
    // progres kalau status sudah bukan in_progress.
    @JsonKey(name: 'remaining_seconds') required double remainingSeconds,
    @JsonKey(name: 'uses_section_timers') required bool usesSectionTimers,
    @JsonKey(name: 'current_section') ExamCurrentSection? currentSection,
    @JsonKey(name: 'tab_switch_count') required int tabSwitchCount,
    @JsonKey(name: 'question_order') ExamQuestionOrder? questionOrder,
    List<ExamQuestion>? questions,
    // Lihat catatan verifikasi di [ExamAnsweredQuestion].
    @Default([]) List<ExamAnsweredQuestion> answers,
  }) = _ExamAttemptModel;

  const ExamAttemptModel._();

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptModelFromJson(json);

  bool get isInProgress => status == ExamAttemptStatus.inProgress;

  /// submitted = ada essay pending dinilai tutor; auto_submitted = waktu
  /// habis; graded = final, boleh tampilkan skor.
  bool get isFinished => !isInProgress;

  bool get isGraded => status == ExamAttemptStatus.graded;

  /// Essay yang belum dinilai tutor -- skor belum final walau attempt
  /// sudah "selesai" dari sisi user.
  bool get isAwaitingGrading => status == ExamAttemptStatus.submitted;

  /// [questions] disusun ulang sesuai urutan acak server di [questionOrder]
  /// -- baik urutan soal maupun urutan opsi per soal -- supaya render UI
  /// persis sama dengan yang dilihat user (server yang menentukan random
  /// seed, bukan client). Kosong kalau attempt bukan in_progress (server
  /// memang tidak mengirim questions/question_order untuk status lain) --
  /// SELALU guard lewat [isInProgress] sebelum pakai ini untuk UI
  /// pengerjaan soal, jangan andalkan list kosong sebagai sinyal loading.
  List<ExamQuestion> get orderedQuestions {
    final qs = questions;
    final order = questionOrder;
    if (qs == null || order == null) return const [];

    final questionsById = {for (final q in qs) q.id: q};
    final optionOrderByQuestion = {
      for (final o in order.options) o.questionId: o.optionIds,
    };

    return [
      for (final qId in order.questions)
        if (questionsById[qId] != null)
          _withReorderedOptions(questionsById[qId]!, optionOrderByQuestion[qId]),
    ];
  }
}

ExamQuestion _withReorderedOptions(ExamQuestion question, List<int>? optionIds) {
  if (optionIds == null || optionIds.isEmpty) return question;

  final optionsById = {for (final o in question.options) o.id: o};
  final reordered = [
    for (final id in optionIds)
      if (optionsById[id] != null) optionsById[id]!,
  ];

  // Fallback: kalau ada opsi yang tidak disebut di question_order.options
  // (harusnya tidak pernah terjadi dari data server), tetap sertakan di
  // akhir daripada hilang diam-diam dari UI.
  final coveredIds = reordered.map((o) => o.id).toSet();
  final missing = question.options.where((o) => !coveredIds.contains(o.id));

  return question.copyWith(options: [...reordered, ...missing]);
}
