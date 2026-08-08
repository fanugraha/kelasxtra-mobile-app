// lib/features/kelas_materi/data/repositories/kelas_materi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../kelas_materi_api_service.dart';
import '../models/kelas_materi_model.dart';

part 'kelas_materi_repository.g.dart';

class KelasMateriRepository {
  KelasMateriRepository(this._api);

  final KelasMateriApiService _api;

  Future<List<ClassSummary>> getClasses() async {
    try {
      return await _api.getClasses();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ClassDetail> getClassDetail(int classId) async {
    try {
      return await _api.getClassDetail(classId);
    } on DioException catch (e) {
      // Dilempar apa adanya (bukan di-null-kan) -- screen butuh
      // ApiException.isForbidden untuk beda-in pesan "belum terdaftar
      // aktif" vs error umum lain (lihat pola sama di TutorEssayQueue).
      throw ApiException.fromDioException(e);
    }
  }

  Future<MaterialItem> getMaterialDetail(int materialId) async {
    try {
      return await _api.getMaterialDetail(materialId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
KelasMateriRepository kelasMateriRepository(KelasMateriRepositoryRef ref) {
  return KelasMateriRepository(ref.watch(kelasMateriApiServiceProvider));
}

