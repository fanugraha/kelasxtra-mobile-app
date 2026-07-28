// lib/features/beranda/data/beranda_api_service.dart
//
// Panggilan HTTP mentah untuk Beranda. Tidak ada logic gabungan di sini --
// itu tanggung jawab BerandaRepository. Service ini murni mapping
// request/response per endpoint, supaya gampang di-mock waktu testing.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import 'models/beranda_models.dart';

part 'beranda_api_service.g.dart';

class BerandaApiService {
  BerandaApiService(this._dio);

  final Dio _dio;

  /// GET /packages/recommended
  Future<RecommendedPackagesResponse> getRecommendedPackages() async {
    final response = await _dio.get('/packages/recommended');
    return RecommendedPackagesResponse.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// GET /my-exams/latest-attempted
  ///
  /// CATATAN PENTING: nama endpoint ini menyesatkan. Kalau user belum
  /// pernah attempt exam (di luar leaderboard batch), backend fallback ke
  /// exam tryout pertama yang boleh diakses user -- lihat
  /// ExamController::latestAttemptedExam() di backend. Jadi exam_id di sini
  /// TIDAK selalu berarti "sedang/pernah dikerjakan user". Attempt yang
  /// terikat exam_batch_id (leaderboard event) juga sengaja diexclude oleh
  /// backend dari pencarian "terakhir dikerjakan".
  ///
  /// Balikan `null` kalau memang tidak ada exam yang bisa direkomendasikan
  /// sama sekali (user belum punya akses ke exam manapun).
  Future<int?> getLatestAttemptedExamId() async {
    final response = await _dio.get('/my-exams/latest-attempted');
    final data = response.data as Map<String, dynamic>;
    return data['exam_id'] as int?;
  }

  /// GET /exams/{examId}/summary
  ///
  /// Dipakai buat lengkapi Continue Card: kasih `title` (exam_id doang
  /// dari latest-attempted tidak cukup buat ditampilkan ke user) dan
  /// `in_progress_attempt_id` (penentu tombol "Lanjutkan" vs "Mulai").
  Future<ExamSummaryResponse> getExamSummary(int examId) async {
    final response = await _dio.get('/exams/$examId/summary');
    return ExamSummaryResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exam-attempts/{attemptId}
  ///
  /// Dipanggil cuma kalau /exams/{id}/summary balikin
  /// in_progress_attempt_id != null. Cuma ambil 2 field (remaining_seconds,
  /// duration_minutes) buat hitung progress -- tidak parse `questions`/
  /// `question_order` karena tidak dipakai di Beranda (itu buat layar
  /// exam_engine, konteks beda).
  Future<ExamAttemptProgress> getExamAttemptProgress(int attemptId) async {
    final response = await _dio.get('/exam-attempts/$attemptId');
    final data = response.data as Map<String, dynamic>;
    return ExamAttemptProgress(
      remainingSeconds: data['remaining_seconds'] as int,
      durationMinutes: data['duration_minutes'] as int,
    );
  }

  /// GET /me/performance-summary
  ///
  /// [programId] SENGAJA wajib dikirim eksplisit oleh caller -- JANGAN
  /// andalkan default backend (`user.preferred_program_id`). Kolom itu
  /// tech debt yang belum pernah diisi untuk user manapun sejauh ini, jadi
  /// kalau program_id tidak dikirim, response bisa balik `no_attempts`
  /// padahal user sebenarnya sudah banyak mengerjakan tryout.
  Future<PerformanceSummary> getPerformanceSummary({int? programId}) async {
    final response = await _dio.get(
      '/me/performance-summary',
      queryParameters: {
        if (programId != null) 'program_id': programId,
      },
    );
    return PerformanceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /my-subscription
  ///
  /// KONFIRMASI dari OpenAPI spec: body dibungkus {"subscription": ...},
  /// null kalau user belum pernah subscribe. Return type nullable
  /// (bukan sentinel .none) karena bentuk field aslinya (id, plan,
  /// status, start_date, end_date) tidak punya representasi "kosong".
  Future<SubscriptionStatus?> getMySubscription() async {
    final response = await _dio.get('/my-subscription');
    final data = response.data as Map<String, dynamic>;
    final subscriptionJson = data['subscription'] as Map<String, dynamic>?;
    if (subscriptionJson == null) return null;
    return SubscriptionStatus.fromJson(subscriptionJson);
  }

  /// GET /promos/active
  ///
  /// KONFIRMASI dari OpenAPI spec: response array polos, sesuai dugaan
  /// awal -- tidak perlu diubah.
  Future<List<PromoBanner>> getActivePromos() async {
    final response = await _dio.get('/promos/active');
    final data = response.data as List<dynamic>;
    return data
        .map((json) => PromoBanner.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /notifications/unread-count
  ///
  /// KONFIRMASI dari OpenAPI spec + response asli: key-nya `count`,
  /// bukan `unread_count` (asumsi awal salah -- badge notifikasi di
  /// header selalu 0 sebelum fix ini, walau backend punya data).
  Future<int> getUnreadNotificationCount() async {
    final response = await _dio.get('/notifications/unread-count');
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }
}

@Riverpod(keepAlive: true)
BerandaApiService berandaApiService(BerandaApiServiceRef ref) {
  return BerandaApiService(ref.watch(dioProvider));
}
