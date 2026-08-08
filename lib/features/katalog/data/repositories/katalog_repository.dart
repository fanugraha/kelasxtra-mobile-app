// lib/features/katalog/data/repositories/katalog_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../katalog_api_service.dart';
import '../models/package_model.dart';
import '../models/promo_model.dart';

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

  /// Return (result, null) kalau valid, (null, pesan error) kalau tidak --
  /// pola sama seperti TutorRepository.gradeEssay: kode 404/422 BUKAN
  /// exception yang perlu ditangani beda-beda oleh UI, cukup pesannya saja
  /// (backend sudah kasih pesan Indonesia yang jelas: "kode tidak
  /// ditemukan", "kedaluwarsa", dll).
  Future<(PromoValidationResult?, String?)> validatePromo({
    required String code,
    int? packageId,
    int? planId,
  }) async {
    try {
      final result = await _api.validatePromo(code: code, packageId: packageId, planId: planId);
      return (result, null);
    } on DioException catch (e) {
      return (null, ApiException.fromDioException(e).message);
    }
  }
}

@riverpod
KatalogRepository katalogRepository(KatalogRepositoryRef ref) {
  return KatalogRepository(ref.watch(katalogApiServiceProvider));
}

