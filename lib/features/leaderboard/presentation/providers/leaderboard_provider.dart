// lib/features/leaderboard/presentation/providers/leaderboard_provider.dart
//
// Fetch sederhana + 1 state lokal untuk exam yang lagi dipilih di dropdown.
// Pola sama seperti latihan_fokus_provider.dart (GET tanpa mutasi lokal ->
// tidak perlu Notifier class), kecuali [selectedLeaderboardExamId] yang
// murni UI state (dropdown), bukan hasil fetch server.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/leaderboard_repository.dart';
import '../../data/models/leaderboard_event_model.dart';
import '../../data/models/leaderboard_model.dart';

export '../../data/models/leaderboard_event_model.dart';
export '../../data/models/leaderboard_model.dart';

part 'leaderboard_provider.g.dart';

/// GET /exams/leaderboard/ranked -- daftar exam yang punya leaderboard
/// aktif periode berjalan, dipakai isi dropdown pemilihan exam.
@riverpod
Future<LeaderboardRankedResponse> leaderboardRankedExams(LeaderboardRankedExamsRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getRankedExams();
}

/// Exam yang lagi dipilih di dropdown -- null berarti belum ada pilihan
/// eksplisit dari user, screen yang default-kan ke exam pertama dari
/// [leaderboardRankedExamsProvider] begitu data itu sampai (lihat
/// leaderboard_screen.dart, bukan di sini, supaya provider ini tidak perlu
/// tahu soal provider lain).
@riverpod
class SelectedLeaderboardExamId extends _$SelectedLeaderboardExamId {
  @override
  int? build() => null;

  void select(int examId) => state = examId;
}

/// GET /exams/{exam}/leaderboard -- Top 50 periode berjalan untuk exam
/// yang dipilih.
@riverpod
Future<LeaderboardIndexResponse> leaderboardEntries(LeaderboardEntriesRef ref, int examId) {
  return ref.watch(leaderboardRepositoryProvider).getLeaderboard(examId);
}

/// GET /exams/{exam}/leaderboard/me -- posisi user login. Null kalau user
/// belum punya ranking di exam+periode ini (lihat catatan repository).
@riverpod
Future<LeaderboardMyPosition?> leaderboardMyPosition(LeaderboardMyPositionRef ref, int examId) {
  return ref.watch(leaderboardRepositoryProvider).getMyPosition(examId);
}

/// GET /leaderboard-events/me -- notifikasi rank berubah milik user
/// sendiri (default backend: 10 menit terakhir). Fetch sekali per buka
/// layar Peringkat + pull-to-refresh, TIDAK auto-polling di background --
/// pola sama seperti provider lain di modul ini, supaya tidak menambah
/// mekanisme baru (timer/websocket) yang belum ada presisinya di project.
@riverpod
Future<LeaderboardMyEventsResponse> leaderboardMyEvents(LeaderboardMyEventsRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getMyEvents();
}

/// GET /leaderboard-events/feed -- event rank berubah milik siswa lain
/// (default backend: 2 menit terakhir).
@riverpod
Future<LeaderboardFeedResponse> leaderboardFeed(LeaderboardFeedRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getFeedEvents();
}
