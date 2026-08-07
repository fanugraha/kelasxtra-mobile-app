// lib/features/privasi/data/privasi_api_service.dart
//
// Panggilan HTTP mentah untuk Privasi. 1 endpoint sederhana, tidak perlu
// Retrofit -- ikuti pola raw Dio modul-modul lain.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

part 'privasi_api_service.g.dart';

class PrivasiApiService {
  PrivasiApiService(this._dio);

  final Dio _dio;

  /// PATCH /user/privacy -- response cuma {"message": "..."}, TIDAK
  /// mengembalikan user terbaru. Caller (repository/provider) yang
  /// bertanggung jawab update local UserModel kalau sukses.
  Future<void> updatePrivacy({required bool hideFromLeaderboardFeed}) async {
    await _dio.patch(
      ApiEndpoints.userPrivacy,
      data: {'hide_from_leaderboard_feed': hideFromLeaderboardFeed},
    );
  }
}

@Riverpod(keepAlive: true)
PrivasiApiService privasiApiService(PrivasiApiServiceRef ref) {
  return PrivasiApiService(ref.watch(dioProvider));
}
