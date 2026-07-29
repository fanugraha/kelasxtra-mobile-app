// lib/features/enrollment/data/enrollment_api_service.dart
//
// Panggilan HTTP mentah untuk Enrollment. Ikuti pola BerandaApiService /
// NotifikasiApiService (raw Dio) -- cuma 1 endpoint, tidak perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/enrollment_model.dart';

part 'enrollment_api_service.g.dart';

class EnrollmentApiService {
  EnrollmentApiService(this._dio);

  final Dio _dio;

  /// GET /my-packages -- paket yang sudah dibeli user (aktif maupun
  /// kedaluwarsa). CATATAN dari spec: Latihan Fokus TIDAK muncul di sini,
  /// itu katalog terbuka lewat /latihan-soal/*, bukan enrollment.
  Future<List<EnrollmentModel>> getMyPackages() async {
    final response = await _dio.get(ApiEndpoints.myPackages);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => EnrollmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
EnrollmentApiService enrollmentApiService(EnrollmentApiServiceRef ref) {
  return EnrollmentApiService(ref.watch(dioProvider));
}
