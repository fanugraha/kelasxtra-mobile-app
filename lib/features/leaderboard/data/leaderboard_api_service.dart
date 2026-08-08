// lib/features/leaderboard/data/leaderboard_api_service.dart
//
// Panggilan HTTP mentah untuk Leaderboard Latihan Soal (mingguan). Ikuti
// pola LatihanFokusApiService (raw Dio) -- 3 endpoint GET sederhana, tidak
// perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/leaderboard_event_model.dart';
import 'models/leaderboard_model.dart';

part 'leaderboard_api_service.g.dart';

class LeaderboardApiService {
  LeaderboardApiService(this._dio);

  final Dio _dio;

  /// GET /exams/leaderboard/ranked
  Future<LeaderboardRankedResponse> getRankedExams() async {
    final response = await _dio.get(ApiEndpoints.examsLeaderboardRanked);
    return LeaderboardRankedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exams/{exam}/leaderboard
  Future<LeaderboardIndexResponse> getLeaderboard(int examId) async {
    final response = await _dio.get(ApiEndpoints.examLeaderboard(examId));
    return LeaderboardIndexResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exams/{exam}/leaderboard/me
  Future<LeaderboardMyPosition> getMyPosition(int examId) async {
    final response = await _dio.get(ApiEndpoints.examLeaderboardMe(examId));
    return LeaderboardMyPosition.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /leaderboard-events/me -- default backend: 10 menit terakhir kalau
  /// [since] tidak diisi. Sengaja tidak expose paging/limit -- backend sudah
  /// batasi maxItems 5.
  Future<LeaderboardMyEventsResponse> getMyEvents({DateTime? since}) async {
    final response = await _dio.get(
      ApiEndpoints.leaderboardEventsMe,
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return LeaderboardMyEventsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /leaderboard-events/feed -- default backend: 2 menit terakhir kalau
  /// [since] tidak diisi (jendela lebih pendek dari /me karena ini feed
  /// publik semua siswa, bukan cuma milik user).
  Future<LeaderboardFeedResponse> getFeedEvents({DateTime? since}) async {
    final response = await _dio.get(
      ApiEndpoints.leaderboardEventsFeed,
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return LeaderboardFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
LeaderboardApiService leaderboardApiService(LeaderboardApiServiceRef ref) {
  return LeaderboardApiService(ref.watch(dioProvider));
}
