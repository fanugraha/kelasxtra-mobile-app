// lib/features/latihan_fokus/data/models/latihan_fokus_model.dart
//
// Model untuk 3 layar Latihan Soal per Topik (tag "Latihan Fokus" di
// kelasxtra-openapi.yaml, semua endpoint x-verified: source-code):
//   Layar 1: GET /latihan-soal/categories               -> LatihanCategoryModel
//   Layar 2: GET /latihan-soal/categories/{id}/topics    -> LatihanTopicModel
//   Layar 3: GET /latihan-soal/topics/{id}/roadmap       -> LatihanRoadmapPartModel
import 'package:freezed_annotation/freezed_annotation.dart';

part 'latihan_fokus_model.freezed.dart';
part 'latihan_fokus_model.g.dart';

@freezed
class LatihanCategoryProgram with _$LatihanCategoryProgram {
  const factory LatihanCategoryProgram({
    int? id,
    String? name,
  }) = _LatihanCategoryProgram;

  factory LatihanCategoryProgram.fromJson(Map<String, dynamic> json) =>
      _$LatihanCategoryProgramFromJson(json);
}

/// Layar 1 -- kategori/mapel (mis. TWK, TIU, TKP) yang punya minimal 1
/// topik dengan part tersedia.
@freezed
class LatihanCategoryModel with _$LatihanCategoryModel {
  const factory LatihanCategoryModel({
    required int id,
    String? code,
    required String name,
    LatihanCategoryProgram? program,
  }) = _LatihanCategoryModel;

  factory LatihanCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanCategoryModelFromJson(json);
}

/// Layar 2 -- topik dalam 1 kategori + progress part yang sudah
/// diselesaikan.
@freezed
class LatihanTopicModel with _$LatihanTopicModel {
  const factory LatihanTopicModel({
    @JsonKey(name: 'topic_id') required int topicId,
    required String name,
    String? code,
    @JsonKey(name: 'total_parts') required int totalParts,
    @JsonKey(name: 'completed_parts') required int completedParts,
  }) = _LatihanTopicModel;

  factory LatihanTopicModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanTopicModelFromJson(json);
}

extension LatihanTopicProgressX on LatihanTopicModel {
  double get progressRatio => totalParts == 0 ? 0 : completedParts / totalParts;
  bool get isFullyCompleted => totalParts > 0 && completedParts >= totalParts;
}

enum LatihanRoadmapPartStatus {
  @JsonValue('completed')
  completed,
  @JsonValue('unlocked')
  unlocked,
  @JsonValue('locked_subscription')
  lockedSubscription,
  @JsonValue('locked_sequence')
  lockedSequence,
}

/// Layar 3 -- 1 part latihan dalam roadmap topik. [examId] dipakai
/// langsung sebagai path param ke `/exams/{examId}/summary` (reuse
/// ExamSummaryScreen dari Exam Engine -- part latihan soal berjalan lewat
/// alur mulai/lanjut yang sama seperti try-out, cuma tanpa exam_batch_id).
@freezed
class LatihanRoadmapPartModel with _$LatihanRoadmapPartModel {
  const factory LatihanRoadmapPartModel({
    @JsonKey(name: 'exam_id') required int examId,
    @JsonKey(name: 'part_number') int? partNumber,
    required String title,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    required LatihanRoadmapPartStatus status,
    @JsonKey(name: 'best_score') double? bestScore,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
  }) = _LatihanRoadmapPartModel;

  factory LatihanRoadmapPartModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanRoadmapPartModelFromJson(json);
}

extension LatihanRoadmapPartX on LatihanRoadmapPartModel {
  bool get isLocked =>
      status == LatihanRoadmapPartStatus.lockedSubscription ||
      status == LatihanRoadmapPartStatus.lockedSequence;
}
