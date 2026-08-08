#!/usr/bin/env bash
set -euo pipefail

# Apply script fitur "Riwayat Semua Percobaan" (GET /exams/{exam}/attempts)
# Jalankan dari root folder kelasxtra-mobile-app.

if [ ! -f pubspec.yaml ]; then
  echo "Jalankan script ini dari root folder kelasxtra-mobile-app (pubspec.yaml tidak ditemukan di sini)."
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree belum bersih -- commit/stash dulu perubahan yang ada sebelum apply patch ini."
  exit 1
fi

PATCH_FILE="$(mktemp)"
cat > "$PATCH_FILE" <<'PATCH_EOF'
diff --git a/lib/core/router/app_router.dart b/lib/core/router/app_router.dart
index d85a52e..bc2ab0c 100644
--- a/lib/core/router/app_router.dart
+++ b/lib/core/router/app_router.dart
@@ -19,6 +19,7 @@ import '../../features/katalog/presentation/screens/katalog_screen.dart';
 import '../../features/katalog/presentation/screens/tryout_screen.dart';
 import '../../features/kelas_materi/presentation/screens/kelas_detail_screen.dart';
 import '../../features/kelas_materi/presentation/screens/kelas_list_screen.dart';
+import '../../features/exam_engine/presentation/screens/exam_attempt_history_screen.dart';
 import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
 import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
 import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
@@ -222,6 +223,13 @@ GoRouter goRouter(GoRouterRef ref) {
           return ExamSummaryScreen(examId: examId);
         },
       ),
+      GoRoute(
+        path: '/exams/:examId/attempts',
+        builder: (context, state) {
+          final examId = int.parse(state.pathParameters['examId']!);
+          return ExamAttemptHistoryScreen(examId: examId);
+        },
+      ),
       GoRoute(
         path: '/exam-attempts/:attemptId',
         builder: (context, state) {
diff --git a/lib/features/exam_engine/data/exam_api_service.dart b/lib/features/exam_engine/data/exam_api_service.dart
index 3a3fd99..6859969 100644
--- a/lib/features/exam_engine/data/exam_api_service.dart
+++ b/lib/features/exam_engine/data/exam_api_service.dart
@@ -8,6 +8,7 @@ import 'package:riverpod_annotation/riverpod_annotation.dart';
 
 import '../../../core/constants/api_endpoints.dart';
 import '../../../core/network/dio_client.dart';
+import 'models/exam_attempt_history_model.dart';
 import 'models/exam_attempt_model.dart';
 import 'models/exam_review_model.dart';
 import 'models/exam_summary_model.dart';
@@ -168,6 +169,19 @@ class ExamApiService {
     final data = response.data as List<dynamic>;
     return data.map((json) => MyExamItem.fromJson(json as Map<String, dynamic>)).toList();
   }
+
+  /// GET /exams/{exam}/attempts -- riwayat SEMUA percobaan yang sudah
+  /// selesai untuk exam ini (beda dari getExamSummary yang cuma balikin
+  /// percobaan pertama & terakhir). Lihat catatan lengkap di
+  /// [ExamAttemptHistoryResponse]. [bankId] opsional untuk try-out
+  /// multi-bank, pola sama seperti getExamSummary.
+  Future<ExamAttemptHistoryResponse> getExamAttempts(int examId, {int? bankId}) async {
+    final response = await _dio.get(
+      ApiEndpoints.examAttempts(examId),
+      queryParameters: bankId != null ? {'bank_id': bankId} : null,
+    );
+    return ExamAttemptHistoryResponse.fromJson(response.data as Map<String, dynamic>);
+  }
 }
 
 @Riverpod(keepAlive: true)
diff --git a/lib/features/exam_engine/data/exam_repository.dart b/lib/features/exam_engine/data/exam_repository.dart
index d86f94b..8e16d91 100644
--- a/lib/features/exam_engine/data/exam_repository.dart
+++ b/lib/features/exam_engine/data/exam_repository.dart
@@ -4,6 +4,7 @@ import 'package:riverpod_annotation/riverpod_annotation.dart';
 
 import '../../../core/network/api_exception.dart';
 import 'exam_api_service.dart';
+import 'models/exam_attempt_history_model.dart';
 import 'models/exam_attempt_model.dart';
 import 'models/exam_review_model.dart';
 import 'models/exam_summary_model.dart';
@@ -138,6 +139,14 @@ class ExamRepository {
       throw ApiException.fromDioException(e);
     }
   }
+
+  Future<ExamAttemptHistoryResponse> getExamAttempts(int examId, {int? bankId}) async {
+    try {
+      return await _api.getExamAttempts(examId, bankId: bankId);
+    } on DioException catch (e) {
+      throw ApiException.fromDioException(e);
+    }
+  }
 }
 
 @riverpod
diff --git a/lib/features/exam_engine/data/models/exam_attempt_history_model.dart b/lib/features/exam_engine/data/models/exam_attempt_history_model.dart
new file mode 100644
index 0000000..ffc6748
--- /dev/null
+++ b/lib/features/exam_engine/data/models/exam_attempt_history_model.dart
@@ -0,0 +1,89 @@
+// lib/features/exam_engine/data/models/exam_attempt_history_model.dart
+//
+// Model untuk GET /exams/{exam}/attempts -- x-verified: source-code,
+// dicocokkan langsung ke ExamController::attempts() di kelasxtra-backend
+// (openapi.yaml masih `x-verified: inferred` untuk endpoint ini).
+//
+// BEDA dari GET /exams/{exam}/summary (lihat [ExamSummaryModel]):
+// - summary() cuma balikin first_attempt & latest_attempt (2 attempt saja).
+// - attempts() balikin SEMUA attempt yang sudah selesai (status submitted/
+//   auto_submitted/graded), diurutkan started_at ASC, masing-masing sudah
+//   dilengkapi attempt_number (1-based, urutan pengerjaan) dan
+//   correct_count PER SECTION (summary() tidak punya ini di section-nya).
+// - Filter status di backend TIDAK termasuk in_progress -- endpoint ini
+//   tidak pernah mengirim attempt yang belum selesai, jadi finished_at
+//   dan started_at selalu ada.
+// - `exam` di sini cuma subset {id, title, passing_score} -- BUKAN
+//   [ExamInfo] penuh (tidak ada duration_minutes/sections/is_free_preview).
+import 'package:freezed_annotation/freezed_annotation.dart';
+
+import 'exam_summary_model.dart';
+
+part 'exam_attempt_history_model.freezed.dart';
+part 'exam_attempt_history_model.g.dart';
+
+@freezed
+class ExamAttemptHistorySectionScore with _$ExamAttemptHistorySectionScore {
+  const factory ExamAttemptHistorySectionScore({
+    required String code,
+    required String name,
+    @JsonKey(name: 'raw_score') required double rawScore,
+    @JsonKey(name: 'correct_count') @Default(0) int correctCount,
+    @JsonKey(name: 'min_passing_score') int? minPassingScore,
+    // null = section ini tidak punya threshold kelulusan sendiri -- pola
+    // sama seperti ExamAttemptSectionScore.passedThreshold di summary.
+    @JsonKey(name: 'passed_threshold') bool? passedThreshold,
+  }) = _ExamAttemptHistorySectionScore;
+
+  factory ExamAttemptHistorySectionScore.fromJson(Map<String, dynamic> json) =>
+      _$ExamAttemptHistorySectionScoreFromJson(json);
+}
+
+@freezed
+class ExamAttemptHistoryItem with _$ExamAttemptHistoryItem {
+  const factory ExamAttemptHistoryItem({
+    @JsonKey(name: 'attempt_id') required int attemptId,
+    @JsonKey(name: 'attempt_number') required int attemptNumber,
+    @JsonKey(name: 'started_at') required DateTime startedAt,
+    @JsonKey(name: 'finished_at') required DateTime finishedAt,
+    required double score,
+    @JsonKey(name: 'correct_count') required int correctCount,
+    @Default([]) List<ExamAttemptHistorySectionScore> sections,
+    // null = exam ini tidak punya aturan kelulusan sama sekali (lihat
+    // Exam::isAttemptPassed) -- pola sama seperti ExamAttemptSummary.passed.
+    bool? passed,
+    // Terisi hanya untuk try-out multi-bank (mis. TWK/TIU/TKP terpisah
+    // attempt) -- null untuk exam single-bank/latihan topik biasa.
+    ExamBankRef? bank,
+  }) = _ExamAttemptHistoryItem;
+
+  factory ExamAttemptHistoryItem.fromJson(Map<String, dynamic> json) =>
+      _$ExamAttemptHistoryItemFromJson(json);
+}
+
+@freezed
+class ExamAttemptHistoryExamInfo with _$ExamAttemptHistoryExamInfo {
+  const factory ExamAttemptHistoryExamInfo({
+    required int id,
+    required String title,
+    @JsonKey(name: 'passing_score') int? passingScore,
+  }) = _ExamAttemptHistoryExamInfo;
+
+  factory ExamAttemptHistoryExamInfo.fromJson(Map<String, dynamic> json) =>
+      _$ExamAttemptHistoryExamInfoFromJson(json);
+}
+
+@freezed
+class ExamAttemptHistoryResponse with _$ExamAttemptHistoryResponse {
+  const factory ExamAttemptHistoryResponse({
+    required ExamAttemptHistoryExamInfo exam,
+    @Default([]) List<ExamAttemptHistoryItem> attempts,
+  }) = _ExamAttemptHistoryResponse;
+
+  const ExamAttemptHistoryResponse._();
+
+  factory ExamAttemptHistoryResponse.fromJson(Map<String, dynamic> json) =>
+      _$ExamAttemptHistoryResponseFromJson(json);
+
+  bool get isEmpty => attempts.isEmpty;
+}
diff --git a/lib/features/exam_engine/presentation/providers/exam_provider.dart b/lib/features/exam_engine/presentation/providers/exam_provider.dart
index 831f945..a703833 100644
--- a/lib/features/exam_engine/presentation/providers/exam_provider.dart
+++ b/lib/features/exam_engine/presentation/providers/exam_provider.dart
@@ -7,11 +7,13 @@
 import 'package:riverpod_annotation/riverpod_annotation.dart';
 
 import '../../data/exam_repository.dart';
+import '../../data/models/exam_attempt_history_model.dart';
 import '../../data/models/exam_review_model.dart';
 import '../../data/models/exam_summary_model.dart';
 import '../../data/models/my_exam_model.dart';
 import '../../data/models/topic_mastery_model.dart';
 
+export '../../data/models/exam_attempt_history_model.dart';
 export '../../data/models/exam_review_model.dart';
 export '../../data/models/exam_summary_model.dart';
 export '../../data/models/my_exam_model.dart';
@@ -61,3 +63,16 @@ Future<TopicMasteryHistoryModel> topicMasteryHistory(TopicMasteryHistoryRef ref,
 Future<List<MyExamItem>> myExams(MyExamsRef ref) {
   return ref.watch(examRepositoryProvider).getMyExams();
 }
+
+/// GET /exams/{exam}/attempts -- riwayat SEMUA percobaan (bukan cuma
+/// pertama/terakhir seperti examSummary). Dipakai ExamAttemptHistoryScreen,
+/// di-buka dari link "Lihat Semua Riwayat" di ExamSummaryScreen. [bankId]
+/// opsional untuk try-out multi-bank.
+@riverpod
+Future<ExamAttemptHistoryResponse> examAttemptHistory(
+  ExamAttemptHistoryRef ref,
+  int examId, {
+  int? bankId,
+}) {
+  return ref.watch(examRepositoryProvider).getExamAttempts(examId, bankId: bankId);
+}
diff --git a/lib/features/exam_engine/presentation/screens/exam_attempt_history_screen.dart b/lib/features/exam_engine/presentation/screens/exam_attempt_history_screen.dart
new file mode 100644
index 0000000..15c99e3
--- /dev/null
+++ b/lib/features/exam_engine/presentation/screens/exam_attempt_history_screen.dart
@@ -0,0 +1,249 @@
+// lib/features/exam_engine/presentation/screens/exam_attempt_history_screen.dart
+//
+// GET /exams/{exam}/attempts -- "Riwayat Semua Percobaan": beda dari
+// ExamSummaryScreen yang cuma tampilkan percobaan pertama & terakhir, layar
+// ini nampilin SEMUA percobaan yang sudah selesai (submitted/auto_submitted/
+// graded), diurutkan attempt_number ASC. Dibuka lewat link "Lihat Semua
+// Riwayat Percobaan" di ExamSummaryScreen -- cuma muncul kalau
+// attemptsCount > 0 di sana.
+//
+// Style kartu sengaja dibuat mirip _AttemptCard di ExamSummaryScreen (badge
+// lulus/tidak, breakdown skor per section) supaya konsisten, ditambah label
+// "Percobaan ke-N" dan tanggal pengerjaan yang tidak ada di summary.
+import 'package:flutter/material.dart';
+import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:go_router/go_router.dart';
+
+import '../../../../core/network/api_exception.dart';
+import '../../../../core/theme/app_theme.dart';
+import '../../../../core/utils/formatters.dart';
+import '../providers/exam_provider.dart';
+
+class ExamAttemptHistoryScreen extends ConsumerWidget {
+  const ExamAttemptHistoryScreen({super.key, required this.examId});
+
+  final int examId;
+
+  @override
+  Widget build(BuildContext context, WidgetRef ref) {
+    final historyAsync = ref.watch(examAttemptHistoryProvider(examId));
+
+    return Scaffold(
+      backgroundColor: AppColors.neutral50,
+      appBar: AppBar(
+        backgroundColor: AppColors.neutral50,
+        title: const Text('Riwayat Percobaan'),
+      ),
+      body: historyAsync.when(
+        loading: () => const Center(child: CircularProgressIndicator()),
+        error: (error, _) => _ErrorState(
+          message: error is ApiException ? error.message : 'Gagal memuat riwayat percobaan',
+          onRetry: () => ref.invalidate(examAttemptHistoryProvider(examId)),
+        ),
+        data: (history) {
+          if (history.isEmpty) return const _EmptyState();
+
+          return RefreshIndicator(
+            onRefresh: () async => ref.invalidate(examAttemptHistoryProvider(examId)),
+            child: ListView(
+              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
+              children: [
+                Text(
+                  history.exam.title,
+                  style: const TextStyle(
+                    color: AppColors.neutral900,
+                    fontSize: 15,
+                    fontWeight: FontWeight.w700,
+                  ),
+                ),
+                const SizedBox(height: 4),
+                Text(
+                  '${history.attempts.length} kali dikerjakan',
+                  style: const TextStyle(color: AppColors.neutral500, fontSize: 12.5),
+                ),
+                const SizedBox(height: 16),
+                // Backend urutkan started_at ASC (attempt_number 1 duluan) --
+                // tampilan dibalik supaya percobaan TERBARU ada di atas,
+                // lebih relevan buat dilihat pertama daripada scroll ke bawah.
+                for (final attempt in history.attempts.reversed) ...[
+                  _AttemptHistoryCard(attempt: attempt),
+                  const SizedBox(height: 12),
+                ],
+              ],
+            ),
+          );
+        },
+      ),
+    );
+  }
+}
+
+class _AttemptHistoryCard extends StatelessWidget {
+  const _AttemptHistoryCard({required this.attempt});
+  final ExamAttemptHistoryItem attempt;
+
+  @override
+  Widget build(BuildContext context) {
+    final passed = attempt.passed;
+
+    return Container(
+      width: double.infinity,
+      padding: const EdgeInsets.all(16),
+      decoration: BoxDecoration(
+        color: Colors.white,
+        borderRadius: BorderRadius.circular(16),
+        border: Border.all(color: AppColors.neutral200),
+      ),
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          Row(
+            children: [
+              Expanded(
+                child: Text(
+                  'Percobaan ke-${attempt.attemptNumber}'
+                  '${attempt.bank != null ? ' \u2022 ${attempt.bank!.title}' : ''}',
+                  style: const TextStyle(
+                    color: AppColors.neutral500,
+                    fontSize: 12,
+                    fontWeight: FontWeight.w600,
+                  ),
+                ),
+              ),
+              if (passed != null)
+                Container(
+                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
+                  decoration: BoxDecoration(
+                    color: passed ? AppColors.success50 : AppColors.danger50,
+                    borderRadius: BorderRadius.circular(20),
+                  ),
+                  child: Text(
+                    passed ? 'Lulus' : 'Belum Lulus',
+                    style: TextStyle(
+                      color: passed ? AppColors.success700 : AppColors.danger600,
+                      fontSize: 10.5,
+                      fontWeight: FontWeight.w700,
+                    ),
+                  ),
+                ),
+            ],
+          ),
+          const SizedBox(height: 6),
+          Text(
+            formatTanggal(attempt.finishedAt.toIso8601String()),
+            style: const TextStyle(color: AppColors.neutral400, fontSize: 11),
+          ),
+          const SizedBox(height: 10),
+          Row(
+            crossAxisAlignment: CrossAxisAlignment.end,
+            children: [
+              Text(
+                attempt.score.toStringAsFixed(0),
+                style: const TextStyle(
+                  color: AppColors.neutral900,
+                  fontSize: 22,
+                  fontWeight: FontWeight.w800,
+                ),
+              ),
+              const SizedBox(width: 6),
+              Padding(
+                padding: const EdgeInsets.only(bottom: 3),
+                child: Text(
+                  '${attempt.correctCount} benar',
+                  style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
+                ),
+              ),
+            ],
+          ),
+          if (attempt.sections.isNotEmpty) ...[
+            const SizedBox(height: 8),
+            for (final section in attempt.sections)
+              Padding(
+                padding: const EdgeInsets.only(top: 4),
+                child: Row(
+                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
+                  children: [
+                    Text(
+                      section.name,
+                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
+                    ),
+                    Text(
+                      '${section.rawScore.toStringAsFixed(0)} '
+                      '(${section.correctCount} benar)',
+                      style: const TextStyle(
+                        color: AppColors.neutral900,
+                        fontSize: 12,
+                        fontWeight: FontWeight.w600,
+                      ),
+                    ),
+                  ],
+                ),
+              ),
+          ],
+          const SizedBox(height: 10),
+          Align(
+            alignment: Alignment.centerRight,
+            child: TextButton(
+              onPressed: () => context.push('/exam-attempts/${attempt.attemptId}/review'),
+              style: TextButton.styleFrom(padding: EdgeInsets.zero),
+              child: const Text('Lihat Pembahasan'),
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+}
+
+class _EmptyState extends StatelessWidget {
+  const _EmptyState();
+
+  @override
+  Widget build(BuildContext context) {
+    return Center(
+      child: Padding(
+        padding: const EdgeInsets.all(24),
+        child: Column(
+          mainAxisSize: MainAxisSize.min,
+          children: [
+            const Icon(Icons.history, color: AppColors.neutral300, size: 48),
+            const SizedBox(height: 12),
+            const Text(
+              'Belum ada percobaan yang selesai',
+              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
+            ),
+          ],
+        ),
+      ),
+    );
+  }
+}
+
+class _ErrorState extends StatelessWidget {
+  const _ErrorState({required this.message, required this.onRetry});
+  final String message;
+  final VoidCallback onRetry;
+
+  @override
+  Widget build(BuildContext context) {
+    return Center(
+      child: Padding(
+        padding: const EdgeInsets.all(24),
+        child: Column(
+          mainAxisSize: MainAxisSize.min,
+          children: [
+            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
+            const SizedBox(height: 12),
+            Text(
+              message,
+              textAlign: TextAlign.center,
+              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
+            ),
+            const SizedBox(height: 12),
+            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
+          ],
+        ),
+      ),
+    );
+  }
+}
diff --git a/lib/features/exam_engine/presentation/screens/exam_summary_screen.dart b/lib/features/exam_engine/presentation/screens/exam_summary_screen.dart
index 58bbef0..060b3f1 100644
--- a/lib/features/exam_engine/presentation/screens/exam_summary_screen.dart
+++ b/lib/features/exam_engine/presentation/screens/exam_summary_screen.dart
@@ -37,7 +37,22 @@ class ExamSummaryScreen extends ConsumerWidget {
               _ExamInfoCard(summary: summary),
               if (summary.hasBeenAttempted) ...[
                 const SizedBox(height: 20),
-                const _SectionTitle(title: 'Percobaan Pertama'),
+                Row(
+                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
+                  children: [
+                    const _SectionTitle(title: 'Percobaan Pertama'),
+                    // Selalu tampil kalau sudah pernah dikerjakan, bukan cuma
+                    // saat attemptsCount > 2 -- link ini satu-satunya jalan
+                    // lihat percobaan DI ANTARA pertama & terakhir (mis.
+                    // percobaan ke-2 dari 3 kali), yang tidak kelihatan di
+                    // kartu firstAttempt/latestAttempt di bawah ini.
+                    TextButton(
+                      onPressed: () => context.push('/exams/$examId/attempts'),
+                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
+                      child: const Text('Lihat Semua Riwayat', style: TextStyle(fontSize: 12.5)),
+                    ),
+                  ],
+                ),
                 const SizedBox(height: 10),
                 _AttemptCard(attempt: summary.firstAttempt!),
                 if (summary.latestAttempt != null &&
PATCH_EOF

if git apply --check "$PATCH_FILE" 2>/dev/null; then
  git apply "$PATCH_FILE"
  echo "Patch berhasil di-apply."
else
  echo "git apply gagal (kemungkinan commit lokal berbeda dari cd6d3da)."
  echo "Coba: git apply --3way \"$PATCH_FILE\"  -- atau kirim commit hash lokal kamu ke Claude untuk regenerate patch."
  rm -f "$PATCH_FILE"
  exit 1
fi
rm -f "$PATCH_FILE"

echo "Lanjut generate file .freezed.dart / .g.dart:"
echo "  dart run build_runner build --delete-conflicting-outputs"
