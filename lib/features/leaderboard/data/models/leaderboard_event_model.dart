// lib/features/leaderboard/data/models/leaderboard_event_model.dart
//
// Model untuk Leaderboard Events -- x-verified: source-code, dibaca dari
// LeaderboardEventController.php + PracticeLeaderboardService.php.
// Event ini di-generate dari jalur yang SAMA dengan Leaderboard Latihan
// Soal mingguan (lihat leaderboard_model.dart) tiap kali
// PracticeLeaderboardService::generateForExam() jalan -- BUKAN dari
// /exam-batches/* (yang menurut audit Fase 6b tidak tersambung ke attempt
// manapun), jadi aman dipakai.
//
// Backend catat event HANYA kalau rank user menembus milestone (Top
// 50/10/3) atau membaik >= threshold posisi -- bukan tiap kali leaderboard
// re-generate. Wajar kalau kedua endpoint ini sering balik `events: []`.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_event_model.freezed.dart';
part 'leaderboard_event_model.g.dart';

/// GET /leaderboard-events/me -- 1 event rank-change milik user sendiri.
/// `oldRank` null berarti ini pertama kali dia masuk ranking periode ini
/// (dan langsung menembus milestone).
@freezed
class LeaderboardMyEvent with _$LeaderboardMyEvent {
  const factory LeaderboardMyEvent({
    required int id,
    @JsonKey(name: 'exam_title') required String examTitle,
    @JsonKey(name: 'old_rank') int? oldRank,
    @JsonKey(name: 'new_rank') required int newRank,
    @JsonKey(name: 'is_milestone') required bool isMilestone,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _LeaderboardMyEvent;

  factory LeaderboardMyEvent.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardMyEventFromJson(json);
}

@freezed
class LeaderboardMyEventsResponse with _$LeaderboardMyEventsResponse {
  const factory LeaderboardMyEventsResponse({
    @Default(<LeaderboardMyEvent>[]) List<LeaderboardMyEvent> events,
  }) = _LeaderboardMyEventsResponse;

  factory LeaderboardMyEventsResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardMyEventsResponseFromJson(json);
}

/// GET /leaderboard-events/feed -- 1 event rank-change milik siswa lain.
/// `displayName` sudah dipotong jadi "Nama I." oleh backend (nama lengkap
/// tidak pernah dikirim) -- jangan diproses ulang di client.
@freezed
class LeaderboardFeedEvent with _$LeaderboardFeedEvent {
  const factory LeaderboardFeedEvent({
    required int id,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'new_rank') required int newRank,
    @JsonKey(name: 'is_milestone') required bool isMilestone,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _LeaderboardFeedEvent;

  factory LeaderboardFeedEvent.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFeedEventFromJson(json);
}

@freezed
class LeaderboardFeedResponse with _$LeaderboardFeedResponse {
  const factory LeaderboardFeedResponse({
    @Default(<LeaderboardFeedEvent>[]) List<LeaderboardFeedEvent> events,
  }) = _LeaderboardFeedResponse;

  factory LeaderboardFeedResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFeedResponseFromJson(json);
}
