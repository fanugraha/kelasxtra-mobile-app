// lib/features/exam_engine/data/exam_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'exam_api_service.dart';
import 'models/exam_attempt_model.dart';
import 'models/exam_review_model.dart';
import 'models/exam_summary_model.dart';

part 'exam_repository.g.dart';

class ExamRepository {
  ExamRepository(this._api);

  final ExamApiService _api;

  /// Lempar [ApiException] biasa untuk error umum. Untuk 2 kasus khusus,
  /// cek lewat getter di ApiException sebelum tampilkan message mentah:
  /// - `e.isPreviousPartIncomplete` (403, Latihan Fokus part sebelumnya
  ///   belum selesai)
  /// - `e.isValidationError` dengan `e.batchStartAt`/`e.batchEndAt` terisi
  ///   (422, try-out batch belum buka/sudah tutup)
  Future<ExamAttemptModel> startExam({
    required int examId,
    int? examBatchId,
    int? bankId,
  }) async {
    try {
      return await _api.startExam(
        examId: examId,
        examBatchId: examBatchId,
        bankId: bankId,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamAttemptModel> getAttempt(int attemptId) async {
    try {
      return await _api.getAttempt(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Lempar [ApiException] dengan `isValidationError=true` kalau waktu
  /// habis / attempt sudah tidak aktif / soal bukan bagian section aktif
  /// -- caller (provider Fase 3) perlu treat ini sebagai sinyal untuk
  /// redirect ke finish/review, bukan sekadar tampilkan error dan retry.
  Future<void> submitAnswer({
    required int attemptId,
    required int questionId,
    int? selectedOptionId,
    String? essayAnswer,
  }) async {
    try {
      await _api.submitAnswer(
        attemptId: attemptId,
        questionId: questionId,
        selectedOptionId: selectedOptionId,
        essayAnswer: essayAnswer,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Sengaja tidak melempar ApiException -- kegagalan lapor tab-switch
  /// bukan hal fatal untuk pengalaman user, jangan sampai ganggu ujian
  /// yang sedang berjalan. Return null kalau request gagal.
  Future<int?> reportTabSwitch(int attemptId) async {
    try {
      return await _api.reportTabSwitch(attemptId);
    } on DioException catch (_) {
      return null;
    }
  }

  Future<ExamAttemptModel> finishAttempt(int attemptId) async {
    try {
      return await _api.finishAttempt(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamSummaryModel> getExamSummary(int examId, {int? bankId}) async {
    try {
      return await _api.getExamSummary(examId, bankId: bankId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ExamListItemModel>> getPackageExams(int packageId) async {
    try {
      return await _api.getPackageExams(packageId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ExamReviewModel> getReview(int attemptId) async {
    try {
      return await _api.getReview(attemptId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
ExamRepository examRepository(ExamRepositoryRef ref) {
  return ExamRepository(ref.watch(examApiServiceProvider));
}
