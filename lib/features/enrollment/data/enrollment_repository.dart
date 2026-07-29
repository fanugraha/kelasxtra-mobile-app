// lib/features/enrollment/data/enrollment_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'enrollment_api_service.dart';
import 'models/enrollment_model.dart';

part 'enrollment_repository.g.dart';

class EnrollmentRepository {
  EnrollmentRepository(this._api);

  final EnrollmentApiService _api;

  Future<List<EnrollmentModel>> getMyPackages() async {
    try {
      return await _api.getMyPackages();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
EnrollmentRepository enrollmentRepository(EnrollmentRepositoryRef ref) {
  return EnrollmentRepository(ref.watch(enrollmentApiServiceProvider));
}
