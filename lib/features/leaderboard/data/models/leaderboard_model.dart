// lib/features/leaderboard/data/models/leaderboard_model.dart
//
// Model untuk Leaderboard Latihan Soal (mingguan) -- x-verified: source-code,
// dibaca langsung dari PracticeLeaderboardController.php + migration
// practice_leaderboards (bukan dari OpenAPI spec, karena endpoint ini belum
// pernah dipakai mobile sebelumnya).
//
// SENGAJA TIDAK menyentuh /exam-batches/* (LeaderboardController /
// ExamBatchController) -- itu leaderboard nasional berbasis exam_batch_id
// yang, berdasar audit Fase 6b (lihat catatan Tryout), TIDAK tersambung ke
// flow attempt siswa manapun (web maupun mobile). Modul ini murni pakai
// jalur "Leaderboard Latihan Soal (mingguan)" yang otomatis ke-generate
// dari attempt biasa (GeneratePracticeLeaderboardJob, tiap Minggu 23:55).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_model.freezed.dart';
part 'leaderboard_model.g.dart';

/// badge_only = menang tapi tidak dapat voucher (syarat reward tidak
/// lolos, mis. peserta < 10). voucher_gold/silver/bronze = rank 1/2/3 dan
/// dapat voucher. Nilai enum persis kolom `reward_type` di migration.
enum LeaderboardRewardType {
  @JsonValue('badge_only')
  badgeOnly,
  @JsonValue('voucher_gold')
  voucherGold,
  @JsonValue('voucher_silver')
  voucherSilver,
  @JsonValue('voucher_bronze')
  voucherBronze,
}

/// GET /exams/leaderboard/ranked -- 1 item exam yang punya leaderboard
/// aktif periode berjalan, dipakai buat dropdown pemilihan exam.
@freezed
class LeaderboardRankedExam with _$LeaderboardRankedExam {
  const factory LeaderboardRankedExam({
    required int id,
    required String title,
    @JsonKey(name: 'participants_count') required int participantsCount,
  }) = _LeaderboardRankedExam;

  factory LeaderboardRankedExam.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardRankedExamFromJson(json);
}

@freezed
class LeaderboardRankedResponse with _$LeaderboardRankedResponse {
  const factory LeaderboardRankedResponse({
    required String periode,
    @Default(<LeaderboardRankedExam>[]) List<LeaderboardRankedExam> data,
  }) = _LeaderboardRankedResponse;

  factory LeaderboardRankedResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardRankedResponseFromJson(json);
}

/// Subset field User yang di-eager-load di PracticeLeaderboardController
/// (`with('user:id,name,level_pendidikan')`) -- BUKAN UserModel penuh dari
/// modul auth, sengaja model terpisah supaya tidak nge-assume field lain
/// dari UserModel ikut selalu ada di response ini.
@freezed
class LeaderboardEntryUser with _$LeaderboardEntryUser {
  const factory LeaderboardEntryUser({
    required int id,
    required String name,
    @JsonKey(name: 'level_pendidikan') String? levelPendidikan,
  }) = _LeaderboardEntryUser;

  factory LeaderboardEntryUser.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryUserFromJson(json);
}

/// GET /exams/{exam}/leaderboard -- 1 baris ranking (Top 50, periode
/// berjalan). `id`/`exam_id`/`user_id`/`periode`/`created_at`/`updated_at`
/// dari controller memang ikut ke-serialize (raw Eloquent model, bukan
/// API Resource) tapi tidak dipakai di UI -- tidak dimodelkan di sini
/// supaya tidak terkesan field itu WAJIB dipakai/stabil kontraknya.
@freezed
class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    @JsonKey(name: 'user_id') required int userId,
    required int ranking,
    @JsonKey(name: 'skor_terbaik') required int skorTerbaik,
    @JsonKey(name: 'reward_type') LeaderboardRewardType? rewardType,
    LeaderboardEntryUser? user,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}

@freezed
class LeaderboardIndexResponse with _$LeaderboardIndexResponse {
  const factory LeaderboardIndexResponse({
    required String periode,
    @Default(<LeaderboardEntry>[]) List<LeaderboardEntry> data,
  }) = _LeaderboardIndexResponse;

  factory LeaderboardIndexResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardIndexResponseFromJson(json);
}

/// GET /exams/{exam}/leaderboard/me -- posisi user login di exam+periode
/// ini. Endpoint mengembalikan 404 kalau user belum punya entri (belum
/// pernah attempt exam ini minggu ini) -- itu KONDISI NORMAL, bukan error,
/// makanya repository menerjemahkan 404 jadi `null`, bukan melempar
/// ApiException (lihat leaderboard_repository.dart).
@freezed
class LeaderboardMyPosition with _$LeaderboardMyPosition {
  const factory LeaderboardMyPosition({
    required String periode,
    required int ranking,
    @JsonKey(name: 'total_peserta') required int totalPeserta,
    @JsonKey(name: 'skor_terbaik') required int skorTerbaik,
    @JsonKey(name: 'reward_type') LeaderboardRewardType? rewardType,
    @JsonKey(name: 'discount_code') String? discountCode,
    @JsonKey(name: 'summary_text') required String summaryText,
  }) = _LeaderboardMyPosition;

  factory LeaderboardMyPosition.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardMyPositionFromJson(json);
}

