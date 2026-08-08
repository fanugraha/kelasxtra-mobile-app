// lib/features/leaderboard/data/leaderboard_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'leaderboard_api_service.dart';
import 'models/leaderboard_event_model.dart';
import 'models/leaderboard_model.dart';

part 'leaderboard_repository.g.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._api);

  final LeaderboardApiService _api;

  Future<LeaderboardRankedResponse> getRankedExams() async {
    try {
      return await _api.getRankedExams();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<LeaderboardIndexResponse> getLeaderboard(int examId) async {
    try {
      return await _api.getLeaderboard(examId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Return null kalau user belum punya ranking di exam+periode ini (404
  /// dari server) -- itu KONDISI NORMAL (belum pernah attempt exam ini
  /// minggu ini), bukan error, jadi TIDAK dilempar sebagai ApiException.
  /// Error selain 404 tetap dilempar seperti biasa.
  Future<LeaderboardMyPosition?> getMyPosition(int examId) async {
    try {
      return await _api.getMyPosition(examId);
    } on DioException catch (e) {
      final apiException = ApiException.fromDioException(e);
      if (apiException.isNotFound) return null;
      throw apiException;
    }
  }

  /// GET /leaderboard-events/me -- notifikasi rank berubah milik user
  /// sendiri. Tidak ada kondisi 404 khusus di endpoint ini (selalu 200,
  /// `events` bisa kosong), jadi tidak perlu penanganan beda seperti
  /// [getMyPosition].
  Future<LeaderboardMyEventsResponse> getMyEvents({DateTime? since}) async {
    try {
      return await _api.getMyEvents(since: since);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /leaderboard-events/feed -- event rank berubah milik siswa lain.
  Future<LeaderboardFeedResponse> getFeedEvents({DateTime? since}) async {
    try {
      return await _api.getFeedEvents(since: since);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
LeaderboardRepository leaderboardRepository(LeaderboardRepositoryRef ref) {
  return LeaderboardRepository(ref.watch(leaderboardApiServiceProvider));
}
