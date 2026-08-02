// lib/features/latihan_fokus/data/latihan_fokus_api_service.dart
//
// Panggilan HTTP mentah untuk Latihan Soal per Topik. Ikuti pola
// EnrollmentApiService / NotifikasiApiService (raw Dio) -- 3 endpoint GET
// sederhana, tidak perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/latihan_fokus_model.dart';

part 'latihan_fokus_api_service.g.dart';

class LatihanFokusApiService {
  LatihanFokusApiService(this._dio);

  final Dio _dio;

  /// GET /latihan-soal/categories -- Layar 1.
  Future<List<LatihanCategoryModel>> getCategories() async {
    final response = await _dio.get(ApiEndpoints.latihanSoalCategories);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanCategoryModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /latihan-soal/categories/{taxonomy}/topics -- Layar 2.
  Future<List<LatihanTopicModel>> getTopics(int taxonomyId) async {
    final response = await _dio.get(ApiEndpoints.latihanSoalTopics(taxonomyId));
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanTopicModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /latihan-soal/topics/{topic}/roadmap -- Layar 3.
  Future<List<LatihanRoadmapPartModel>> getRoadmap(int topicId) async {
    final response = await _dio.get(ApiEndpoints.latihanSoalRoadmap(topicId));
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanRoadmapPartModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
LatihanFokusApiService latihanFokusApiService(LatihanFokusApiServiceRef ref) {
  return LatihanFokusApiService(ref.watch(dioProvider));
}
