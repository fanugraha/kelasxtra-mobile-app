// lib/features/tutor/data/tutor_api_service.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/tutor_essay_model.dart';

part 'tutor_api_service.g.dart';

class TutorApiService {
  TutorApiService(this._dio);

  final Dio _dio;

  /// GET /tutor/essay-queue -- role-gated (tutor/admin), 403 kalau bukan.
  Future<TutorEssayQueueResponse> getEssayQueue() async {
    final response = await _dio.get(ApiEndpoints.tutorEssayQueue);
    return TutorEssayQueueResponse.fromJson(
      sanitizeEssayQueueJson(response.data as Map<String, dynamic>),
    );
  }

  /// POST /tutor/essay-answers/{answer}/grade -- response-nya
  /// {message, data: ExamAttempt (skor sudah dihitung ulang)}, tapi UI
  /// tutor tidak butuh detail attempt itu (bukan konteks pengerjaan
  /// soal), jadi sengaja tidak diparse -- cukup tahu request sukses
  /// (tidak throw) atau tidak.
  Future<void> gradeEssay({required int answerId, required bool isCorrect}) async {
    await _dio.post(
      ApiEndpoints.tutorGradeEssay(answerId),
      data: {'is_correct': isCorrect},
    );
  }
}

@Riverpod(keepAlive: true)
TutorApiService tutorApiService(TutorApiServiceRef ref) {
  return TutorApiService(ref.watch(dioProvider));
}
