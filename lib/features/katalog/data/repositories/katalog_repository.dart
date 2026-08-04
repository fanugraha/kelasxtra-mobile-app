// lib/features/katalog/data/repositories/katalog_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../katalog_api_service.dart';
import '../models/package_model.dart';

part 'katalog_repository.g.dart';

class KatalogRepository {
  KatalogRepository(this._api);

  final KatalogApiService _api;

  Future<List<PackageModel>> getPackages({int? programId}) async {
    try {
      return await _api.getPackages(programId: programId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    try {
      return await _api.getPackageDetail(packageId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
KatalogRepository katalogRepository(KatalogRepositoryRef ref) {
  return KatalogRepository(ref.watch(katalogApiServiceProvider));
}
