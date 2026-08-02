// lib/features/leaderboard/data/leaderboard_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'leaderboard_api_service.dart';
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
}

@riverpod
LeaderboardRepository leaderboardRepository(LeaderboardRepositoryRef ref) {
  return LeaderboardRepository(ref.watch(leaderboardApiServiceProvider));
}

