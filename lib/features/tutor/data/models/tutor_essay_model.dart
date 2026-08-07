// lib/features/tutor/data/models/tutor_essay_model.dart
//
// Model untuk antrian penilaian essay (role-gated: tutor/admin).
// GET /tutor/essay-queue -- x-verified: source-code untuk field top-level
// (id, needs_manual_grading, essay_answer, attempt.user.{id,name}), TAPI
// field `question` di spec CUMA "type: object" tanpa properti terdokumentasi
// sama sekali -- beda dari endpoint lain di project ini yang semuanya
// full-typed. Lihat sanitizeEssayQueueJson di bawah untuk cara field itu
// ditangani.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutor_essay_model.freezed.dart';
part 'tutor_essay_model.g.dart';

@freezed
class TutorEssayAttemptUser with _$TutorEssayAttemptUser {
  const factory TutorEssayAttemptUser({
    required int id,
    required String name,
  }) = _TutorEssayAttemptUser;

  factory TutorEssayAttemptUser.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayAttemptUserFromJson(json);
}

@freezed
class TutorEssayAttemptRef with _$TutorEssayAttemptRef {
  const factory TutorEssayAttemptRef({
    TutorEssayAttemptUser? user,
  }) = _TutorEssayAttemptRef;

  factory TutorEssayAttemptRef.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayAttemptRefFromJson(json);
}

@freezed
class TutorEssayQueueItem with _$TutorEssayQueueItem {
  const factory TutorEssayQueueItem({
    // Ini id JAWABAN (answer), bukan id soal -- dipakai langsung sebagai
    // path param {answer} di POST /tutor/essay-answers/{answer}/grade.
    required int id,
    @JsonKey(name: 'needs_manual_grading') @Default(true) bool needsManualGrading,
    @JsonKey(name: 'essay_answer') String? essayAnswer,
    // x-verified: UNVERIFIED. Disuntik sanitizeEssayQueueJson dari
    // question.question_text -- BUKAN key asli response (spec tidak kasih
    // skema apa pun untuk `question`). Tebakan paling masuk akal (tutor
    // pasti butuh baca soal buat menilai), belum pernah dicocokkan ke
    // response asli. Null kalau backend ternyata tidak kirim field itu --
    // UI HARUS fallback ke pesan generik, jangan asumsikan selalu ada.
    @JsonKey(name: '_question_text') String? questionText,
    TutorEssayAttemptRef? attempt,
  }) = _TutorEssayQueueItem;

  factory TutorEssayQueueItem.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayQueueItemFromJson(json);
}

@freezed
class TutorEssayQueueResponse with _$TutorEssayQueueResponse {
  const factory TutorEssayQueueResponse({
    // Laravel paginator -- cuma `data` yang didokumentasikan spec (bukan
    // links/meta), jadi MVP ini cuma render halaman pertama (20 item),
    // belum ada "muat lebih banyak". Field paginasi lain sengaja tidak
    // dimodelkan supaya tidak berasumsi ada, bukan dihilangkan sengaja.
    @Default(<TutorEssayQueueItem>[]) List<TutorEssayQueueItem> data,
  }) = _TutorEssayQueueResponse;

  factory TutorEssayQueueResponse.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayQueueResponseFromJson(json);
}

/// Suntik `_question_text` dari question.question_text SEBELUM fromJson
/// standar dipanggil -- BUKAN override TutorEssayQueueItem.fromJson
/// langsung, karena itu bikin freezed skip generate toJson() juga untuk
/// class itu (pelajaran dari kasus PerformanceSection, lihat catatan di
/// beranda_models.dart). Pola sanitasi eksternal ini sudah 2x terbukti
/// aman dipakai di project ini.
Map<String, dynamic> sanitizeEssayQueueJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);
  final dataRaw = sanitized['data'];
  if (dataRaw is List) {
    sanitized['data'] = dataRaw.map((item) {
      if (item is! Map) return item;
      final itemMap = Map<String, dynamic>.from(item);
      final questionRaw = itemMap['question'];
      if (questionRaw is Map && questionRaw['question_text'] is String) {
        itemMap['_question_text'] = questionRaw['question_text'];
      }
      return itemMap;
    }).toList();
  }
  return sanitized;
}
