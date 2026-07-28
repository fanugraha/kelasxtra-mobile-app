// lib/features/beranda/data/beranda_repository.dart
//
// Gabungkan endpoint jadi 1 BerandaRawData buat layar Beranda:
//   - GET /packages/recommended
//   - GET /my-exams/latest-attempted (+ /exams/{id}/summary,
//     + /exam-attempts/{id} kalau ada in_progress_attempt_id)
//   - GET /me/performance-summary
//   - GET /my-subscription
//   - GET /promos/active
//   - GET /notifications/unread-count
//
// SENGAJA tidak tahu soal user/auth (userName, dsb) -- itu digabung di
// BerandaNotifier (presentation/), bukan di sini. Tidak ada domain/ layer
// untuk fitur ini (lihat struktur folder project -- beranda cuma agregasi
// tampilan, bukan business logic sendiri).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'beranda_api_service.dart';
import 'models/beranda_models.dart';

part 'beranda_repository.g.dart';

class BerandaRepository {
  BerandaRepository(this._api);

  final BerandaApiService _api;

  Future<BerandaRawData> getBerandaData() async {
    // Semua panggilan independen mulai duluan (Future langsung jalan
    // begitu dibuat), baru await berurutan sesuai kebutuhan data --
    // kecuali performance & exam summary yang butuh programId/examId dari
    // call lain, jadi menunggu itu dulu baru dimulai.
    final recommendedFuture = _api.getRecommendedPackages();
    final latestExamIdFuture = _api.getLatestAttemptedExamId();
    final subscriptionFuture = _api.getMySubscription();
    final promosFuture = _api.getActivePromos();
    final unreadCountFuture = _api.getUnreadNotificationCount();

    final recommended = await recommendedFuture;
    final latestExamId = await latestExamIdFuture;

    // program_id WAJIB dikirim eksplisit -- lihat catatan di
    // BerandaApiService.getPerformanceSummary(). Fallback: program dari
    // packages/recommended (based_on_program_id). Kalau itu pun null
    // (user baru/guest, belum pernah transaksi), biarkan tidak terkirim --
    // backend akan balikin state: no_attempts, representasi yang memang
    // benar untuk user semacam ini, bukan bug.
    final programId = recommended.basedOnProgramId;

    final performanceFuture = _api.getPerformanceSummary(programId: programId);
    final examSummaryFuture =
        latestExamId != null ? _api.getExamSummary(latestExamId) : null;

    final performance = await performanceFuture;
    final examSummary =
        examSummaryFuture != null ? await examSummaryFuture : null;

    final continueExam = examSummary == null
        ? null
        : await _buildContinueExamData(examSummary);

    final recommendedPackages =
        recommended.packages.map(RecommendedPackage.fromPackage).toList();

    final subscription = await subscriptionFuture;
    final promoBanners = await promosFuture;
    final unreadNotificationCount = await unreadCountFuture;

    return BerandaRawData(
      recommendedPackages: recommendedPackages,
      continueExam: continueExam,
      performance: performance,
      subscription: subscription,
      promoBanners: promoBanners,
      unreadNotificationCount: unreadNotificationCount,
    );
  }

  Future<ContinueExamData> _buildContinueExamData(
    ExamSummaryResponse examSummary,
  ) async {
    final attemptId = examSummary.inProgressAttemptId;

    // Tidak ada attempt in_progress -- exam_id ini murni rekomendasi
    // (fallback dari backend, lihat catatan di
    // BerandaApiService.getLatestAttemptedExamId()), belum pernah
    // dikerjakan. Progress 0, tidak perlu panggilan tambahan.
    if (attemptId == null) {
      return ContinueExamData(
        examId: examSummary.exam.id,
        title: examSummary.exam.title,
        progress: 0.0,
      );
    }

    final attemptProgress = await _api.getExamAttemptProgress(attemptId);
    final totalSeconds = attemptProgress.durationMinutes * 60;
    final progress = totalSeconds > 0
        ? (1 - (attemptProgress.remainingSeconds / totalSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return ContinueExamData(
      examId: examSummary.exam.id,
      title: examSummary.exam.title,
      progress: progress,
      inProgressAttemptId: attemptId,
    );
  }
}

@riverpod
BerandaRepository berandaRepository(BerandaRepositoryRef ref) {
  return BerandaRepository(ref.watch(berandaApiServiceProvider));
}
