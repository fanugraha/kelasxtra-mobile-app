// lib/features/kelas_materi/data/kelas_materi_api_service.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/kelas_materi_model.dart';

part 'kelas_materi_api_service.g.dart';

class KelasMateriApiService {
  KelasMateriApiService(this._dio);

  final Dio _dio;

  /// GET /classes -- x-verified: source-code.
  Future<List<ClassSummary>> getClasses() async {
    final response = await _dio.get(ApiEndpoints.classes);
    final data = response.data as List;
    return data.map((e) => ClassSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /classes/{class} -- x-verified: UNVERIFIED (lihat catatan di
  /// kelas_materi_model.dart). 403 kalau belum terdaftar aktif di kelas
  /// ini -- dibiarkan lempar DioException, ditangani di repository.
  Future<ClassDetail> getClassDetail(int classId) async {
    final response = await _dio.get(ApiEndpoints.classDetail(classId));
    return ClassDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /materials/{material} -- x-verified: source-code. Dipakai kalau
  /// materi dibuka langsung dari luar konteks ClassDetail (mis. deep link),
  /// bukan dari list materials di ClassDetail (yang sudah datang dari
  /// sanitizeClassDetailJson).
  Future<MaterialItem> getMaterialDetail(int materialId) async {
    final response = await _dio.get(ApiEndpoints.materialDetail(materialId));
    return MaterialItem.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
KelasMateriApiService kelasMateriApiService(KelasMateriApiServiceRef ref) {
  return KelasMateriApiService(ref.watch(dioProvider));
}

