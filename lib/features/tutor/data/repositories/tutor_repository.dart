// lib/features/tutor/data/repositories/tutor_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/tutor_essay_model.dart';
import '../tutor_api_service.dart';

part 'tutor_repository.g.dart';

class TutorRepository {
  TutorRepository(this._api);

  final TutorApiService _api;

  Future<List<TutorEssayQueueItem>> getEssayQueue() async {
    try {
      final response = await _api.getEssayQueue();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Return null kalau sukses, pesan error kalau gagal (422: jawaban ini
  /// bukan essay/sudah dinilai -- lihat spec).
  Future<String?> gradeEssay({required int answerId, required bool isCorrect}) async {
    try {
      await _api.gradeEssay(answerId: answerId, isCorrect: isCorrect);
      return null;
    } on DioException catch (e) {
      return ApiException.fromDioException(e).message;
    }
  }
}

@riverpod
TutorRepository tutorRepository(TutorRepositoryRef ref) {
  return TutorRepository(ref.watch(tutorApiServiceProvider));
}
