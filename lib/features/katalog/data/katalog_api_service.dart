// lib/features/katalog/data/katalog_api_service.dart
//
// Panggilan HTTP mentah untuk katalog paket (beli baru) -- GET /packages
// TIDAK punya filter `type` di server (cuma `program_id`, lihat spec),
// jadi filter per PackageType (reguler=Tryout, latihan_soal=Latihan Soal)
// dilakukan client-side di provider/screen, bukan di query param.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/package_model.dart';
import 'models/promo_model.dart';

part 'katalog_api_service.g.dart';

class KatalogApiService {
  KatalogApiService(this._dio);

  final Dio _dio;

  /// GET /packages -- daftar semua paket yang bisa dibeli (bukan yang
  /// sudah dimiliki user -- itu /my-packages, lihat EnrollmentRepository).
  Future<List<PackageModel>> getPackages({int? programId}) async {
    final response = await _dio.get(
      ApiEndpoints.packages,
      queryParameters: programId != null ? {'program_id': programId} : null,
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => PackageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    final response = await _dio.get(ApiEndpoints.packageDetail(packageId));
    return PackageModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /promos/validate -- pre-check kode promo (tombol "Terapkan"),
  /// TIDAK bikin transaksi. Salah satu dari [packageId]/[planId] wajib
  /// diisi (sama seperti aturan checkout) -- dibiarkan backend yang
  /// validasi kombinasinya, client tidak menduplikasi aturan itu.
  Future<PromoValidationResult> validatePromo({
    required String code,
    int? packageId,
    int? planId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.promosValidate,
      data: {
        'code': code,
        if (packageId != null) 'package_id': packageId,
        if (planId != null) 'plan_id': planId,
      },
    );
    return PromoValidationResult.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
KatalogApiService katalogApiService(KatalogApiServiceRef ref) {
  return KatalogApiService(ref.watch(dioProvider));
}

