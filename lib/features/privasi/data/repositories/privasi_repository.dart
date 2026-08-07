// lib/features/privasi/data/repositories/privasi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../privasi_api_service.dart';

part 'privasi_repository.g.dart';

class PrivasiRepository {
  PrivasiRepository(this._api);

  final PrivasiApiService _api;

  Future<void> updatePrivacy({required bool hideFromLeaderboardFeed}) async {
    try {
      await _api.updatePrivacy(hideFromLeaderboardFeed: hideFromLeaderboardFeed);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
PrivasiRepository privasiRepository(PrivasiRepositoryRef ref) {
  return PrivasiRepository(ref.watch(privasiApiServiceProvider));
}
