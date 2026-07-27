/// Semua path endpoint KelasXtra API.
/// Base URL diatur terpisah di [ApiConfig] (lib/core/config/env.dart)
/// supaya gampang ganti sandbox <-> production.
abstract class ApiEndpoints {
  // ---------------- Auth ----------------
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String googleLogin = '/auth/google';
  static const String resendVerification = '/email/verification-notification';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String me = '/auth/me';
  static const String profile = '/auth/profile';
  static const String changePassword = '/auth/password';
  static const String logout = '/auth/logout';

  // ---------------- Katalog ----------------
  static const String programs = '/programs';
  static const String packages = '/packages';
  static const String packagesRecommended = '/packages/recommended';
  static const String packagesFocusTopics = '/packages/focus-topics';
  static String packageDetail(int id) => '/packages/$id';
  static const String subscriptionPlans = '/subscription-plans';
  static const String articles = '/articles';
  static String articleDetail(String slug) => '/articles/$slug';
  static const String promosActive = '/promos/active';
  static const String promosValidate = '/promos/validate';
  static const String tutors = '/tutors';
  static const String testimonials = '/testimonials';

  // ---------------- Transaksi & Subscription ----------------
  static const String checkout = '/transactions/checkout';
  static const String transactions = '/transactions';
  static String transactionDetail(int id) => '/transactions/$id';
  static String transactionResume(int id) => '/transactions/$id/resume';
  static const String mySubscription = '/my-subscription';

  // ---------------- Enrollment ----------------
  static const String myPackages = '/my-packages';

  // ---------------- Exam Engine ----------------
  static const String examsStart = '/exams/start';
  static String examAttemptDetail(int attemptId) => '/exam-attempts/$attemptId';
  static String examAttemptAnswer(int attemptId) => '/exam-attempts/$attemptId/answer';
  static String examAttemptTabSwitch(int attemptId) => '/exam-attempts/$attemptId/tab-switch';
  static String examAttemptFinish(int attemptId) => '/exam-attempts/$attemptId/finish';
  static String examAttemptReview(int attemptId) => '/exam-attempts/$attemptId/review';
  static String examSummary(int examId) => '/exams/$examId/summary';
  static String examBanks(int examId) => '/exams/$examId/banks';
  static String examAttempts(int examId) => '/exams/$examId/attempts';
  static const String myExamsLatestAttempted = '/my-exams/latest-attempted';
  static const String myExams = '/my-exams';
  static String packageExams(int packageId) => '/packages/$packageId/exams';
  static const String performanceSummary = '/me/performance-summary';
  static const String topicPerformance = '/me/topic-performance';
  static const String topicMasteryHistory = '/me/topic-mastery-history';

  // ---------------- Latihan Fokus ----------------
  static const String latihanSoalCategories = '/latihan-soal/categories';
  static String latihanSoalTopics(int taxonomyId) => '/latihan-soal/categories/$taxonomyId/topics';
  static String latihanSoalRoadmap(int topicId) => '/latihan-soal/topics/$topicId/roadmap';

  // ---------------- Leaderboard ----------------
  static const String examBatches = '/exam-batches';
  static String examBatchLeaderboard(int batchId) => '/exam-batches/$batchId/leaderboard';
  static String examBatchLeaderboardMe(int batchId) => '/exam-batches/$batchId/leaderboard/me';
  static const String examsLeaderboardRanked = '/exams/leaderboard/ranked';
  static String examLeaderboard(int examId) => '/exams/$examId/leaderboard';
  static String examLeaderboardMe(int examId) => '/exams/$examId/leaderboard/me';
  static const String leaderboardEventsMe = '/leaderboard-events/me';
  static const String leaderboardEventsFeed = '/leaderboard-events/feed';

  // ---------------- Notifikasi ----------------
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';

  // ---------------- Kelas & Materi ----------------
  static const String classes = '/classes';
  static String classDetail(int id) => '/classes/$id';
  static String materialDetail(int id) => '/materials/$id';

  // ---------------- Privasi ----------------
  static const String userPrivacy = '/user/privacy';

  // ---------------- Tutor (role-gated) ----------------
  static const String tutorEssayQueue = '/tutor/essay-queue';
  static String tutorGradeEssay(int answerId) => '/tutor/essay-answers/$answerId/grade';
}
