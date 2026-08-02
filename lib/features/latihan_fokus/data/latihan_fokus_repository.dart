// lib/features/latihan_fokus/data/latihan_fokus_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'latihan_fokus_api_service.dart';
import 'models/latihan_fokus_model.dart';

part 'latihan_fokus_repository.g.dart';

class LatihanFokusRepository {
  LatihanFokusRepository(this._api);

  final LatihanFokusApiService _api;

  Future<List<LatihanCategoryModel>> getCategories() async {
    try {
      return await _api.getCategories();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<LatihanTopicModel>> getTopics(int taxonomyId) async {
    try {
      return await _api.getTopics(taxonomyId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<LatihanRoadmapPartModel>> getRoadmap(int topicId) async {
    try {
      return await _api.getRoadmap(topicId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
LatihanFokusRepository latihanFokusRepository(LatihanFokusRepositoryRef ref) {
  return LatihanFokusRepository(ref.watch(latihanFokusApiServiceProvider));
}
