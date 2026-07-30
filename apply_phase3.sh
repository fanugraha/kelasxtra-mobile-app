mkdir -p lib/features/exam_engine/presentation/widgets

cat > lib/features/exam_engine/data/models/exam_attempt_model.dart << 'EOF_MODEL'
// lib/features/exam_engine/data/models/exam_attempt_model.dart
//
// Model ExamAttempt -- bentuk response POST /exams/start, GET
// /exam-attempts/{id}, POST .../finish. Field & tipe cocok dengan schema
// ExamAttempt di kelasxtra-openapi.yaml (x-verified: source-code, dari
// ExamAttemptResource.php).
//
// PENTING: `question_order` dan `questions` HANYA muncul dari server kalau
// status = in_progress; `current_section` HANYA ada kalau in_progress DAN
// uses_section_timers=true. Ketiganya nullable di sini -- JANGAN diakses
// tanpa guard status di provider/UI (lihat catatan di area kelasxtra).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_attempt_model.freezed.dart';
part 'exam_attempt_model.g.dart';

enum ExamAttemptStatus {
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('submitted')
  submitted,
  @JsonValue('auto_submitted')
  autoSubmitted,
  @JsonValue('graded')
  graded,
}

enum ExamQuestionType {
  @JsonValue('pg')
  pg,
  @JsonValue('essay')
  essay,
}

@freezed
class ExamCurrentSection with _$ExamCurrentSection {
  const factory ExamCurrentSection({
    required int id,
    required String code,
    required String name,
    required int order,
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    // Belum ada data asli untuk field ini (uses_section_timers=false pada
    // exam yang sudah ditest) -- dibuat double untuk konsisten dengan
    // remaining_seconds di level attempt yang terbukti desimal. VERIFIKASI
    // ULANG begitu ada exam dengan uses_section_timers=true.
    @JsonKey(name: 'remaining_seconds') double? remainingSeconds,
  }) = _ExamCurrentSection;

  factory ExamCurrentSection.fromJson(Map<String, dynamic> json) =>
      _$ExamCurrentSectionFromJson(json);
}

@freezed
class ExamQuestionOrderOption with _$ExamQuestionOrderOption {
  const factory ExamQuestionOrderOption({
    @JsonKey(name: 'question_id') required int questionId,
    @JsonKey(name: 'option_ids') required List<int> optionIds,
  }) = _ExamQuestionOrderOption;

  factory ExamQuestionOrderOption.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionOrderOptionFromJson(json);
}

/// Urutan tampil soal & opsi HASIL PENGACAKAN SERVER untuk attempt ini --
/// dipakai untuk merender `questions`/`options` sesuai urutan yang sama
/// persis dengan yang dilihat user (server yang menentukan random seed,
/// bukan client).
@freezed
class ExamQuestionOrder with _$ExamQuestionOrder {
  const factory ExamQuestionOrder({
    required List<int> questions,
    @Default([]) List<ExamQuestionOrderOption> options,
  }) = _ExamQuestionOrder;

  factory ExamQuestionOrder.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionOrderFromJson(json);
}

@freezed
class ExamQuestionCategory with _$ExamQuestionCategory {
  const factory ExamQuestionCategory({
    required String code,
    required String name,
  }) = _ExamQuestionCategory;

  factory ExamQuestionCategory.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionCategoryFromJson(json);
}

@freezed
class ExamOption with _$ExamOption {
  const factory ExamOption({
    required int id,
    @JsonKey(name: 'option_text') required String optionText,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _ExamOption;

  factory ExamOption.fromJson(Map<String, dynamic> json) =>
      _$ExamOptionFromJson(json);
}

@freezed
class ExamQuestion with _$ExamQuestion {
  const factory ExamQuestion({
    required int id,
    @JsonKey(name: 'question_text') required String questionText,
    @JsonKey(name: 'media_type') String? mediaType,
    @JsonKey(name: 'media_url') String? mediaUrl,
    required ExamQuestionType type,
    ExamQuestionCategory? category,
    @Default([]) List<ExamOption> options,
  }) = _ExamQuestion;

  const ExamQuestion._();

  factory ExamQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamQuestionFromJson(json);

  bool get isEssay => type == ExamQuestionType.essay;
}

/// Jawaban yang sudah tersimpan di server untuk attempt ini -- dipakai
/// untuk resume (mis. app di-kill lalu dibuka lagi selagi attempt masih
/// in_progress). x-verified: INFERRED, bukan source-code -- response
/// `answers: []` selalu kosong sejauh ini karena testing selalu attempt
/// baru tanpa jawaban tersimpan. Bentuk field di bawah adalah tebakan
/// paling masuk akal berdasar payload POST .../answer (question_id +
/// selected_option_id/essay_answer). VERIFIKASI ULANG begitu ada attempt
/// in_progress yang sudah punya jawaban lalu di-GET ulang.
@freezed
class ExamAnsweredQuestion with _$ExamAnsweredQuestion {
  const factory ExamAnsweredQuestion({
    @JsonKey(name: 'question_id') required int questionId,
    @JsonKey(name: 'selected_option_id') int? selectedOptionId,
    @JsonKey(name: 'essay_answer') String? essayAnswer,
  }) = _ExamAnsweredQuestion;

  factory ExamAnsweredQuestion.fromJson(Map<String, dynamic> json) =>
      _$ExamAnsweredQuestionFromJson(json);
}

@freezed
class ExamAttemptModel with _$ExamAttemptModel {
  const factory ExamAttemptModel({
    required int id,
    @JsonKey(name: 'exam_id') required int examId,
    @JsonKey(name: 'exam_batch_id') int? examBatchId,
    @JsonKey(name: 'bank_id') int? bankId,
    required ExamAttemptStatus status,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'finished_at') DateTime? finishedAt,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    // Desimal di API asli (mis. 5999.053557), BUKAN integer -- "0 kalau
    // status bukan in_progress" (spec) -- jangan dipakai untuk hitung
    // progres kalau status sudah bukan in_progress.
    @JsonKey(name: 'remaining_seconds') required double remainingSeconds,
    @JsonKey(name: 'uses_section_timers') required bool usesSectionTimers,
    @JsonKey(name: 'current_section') ExamCurrentSection? currentSection,
    @JsonKey(name: 'tab_switch_count') required int tabSwitchCount,
    @JsonKey(name: 'question_order') ExamQuestionOrder? questionOrder,
    List<ExamQuestion>? questions,
    // Lihat catatan verifikasi di [ExamAnsweredQuestion].
    @Default([]) List<ExamAnsweredQuestion> answers,
  }) = _ExamAttemptModel;

  const ExamAttemptModel._();

  factory ExamAttemptModel.fromJson(Map<String, dynamic> json) =>
      _$ExamAttemptModelFromJson(json);

  bool get isInProgress => status == ExamAttemptStatus.inProgress;

  /// submitted = ada essay pending dinilai tutor; auto_submitted = waktu
  /// habis; graded = final, boleh tampilkan skor.
  bool get isFinished => !isInProgress;

  bool get isGraded => status == ExamAttemptStatus.graded;

  /// Essay yang belum dinilai tutor -- skor belum final walau attempt
  /// sudah "selesai" dari sisi user.
  bool get isAwaitingGrading => status == ExamAttemptStatus.submitted;

  /// [questions] disusun ulang sesuai urutan acak server di [questionOrder]
  /// -- baik urutan soal maupun urutan opsi per soal -- supaya render UI
  /// persis sama dengan yang dilihat user (server yang menentukan random
  /// seed, bukan client). Kosong kalau attempt bukan in_progress (server
  /// memang tidak mengirim questions/question_order untuk status lain) --
  /// SELALU guard lewat [isInProgress] sebelum pakai ini untuk UI
  /// pengerjaan soal, jangan andalkan list kosong sebagai sinyal loading.
  List<ExamQuestion> get orderedQuestions {
    final qs = questions;
    final order = questionOrder;
    if (qs == null || order == null) return const [];

    final questionsById = {for (final q in qs) q.id: q};
    final optionOrderByQuestion = {
      for (final o in order.options) o.questionId: o.optionIds,
    };

    return [
      for (final qId in order.questions)
        if (questionsById[qId] != null)
          _withReorderedOptions(questionsById[qId]!, optionOrderByQuestion[qId]),
    ];
  }
}

ExamQuestion _withReorderedOptions(ExamQuestion question, List<int>? optionIds) {
  if (optionIds == null || optionIds.isEmpty) return question;

  final optionsById = {for (final o in question.options) o.id: o};
  final reordered = [
    for (final id in optionIds)
      if (optionsById[id] != null) optionsById[id]!,
  ];

  // Fallback: kalau ada opsi yang tidak disebut di question_order.options
  // (harusnya tidak pernah terjadi dari data server), tetap sertakan di
  // akhir daripada hilang diam-diam dari UI.
  final coveredIds = reordered.map((o) => o.id).toSet();
  final missing = question.options.where((o) => !coveredIds.contains(o.id));

  return question.copyWith(options: [...reordered, ...missing]);
}
EOF_MODEL

cat > lib/features/exam_engine/presentation/providers/exam_attempt_state.dart << 'EOF_STATE'
// lib/features/exam_engine/presentation/providers/exam_attempt_state.dart
//
// State lokal 1 sesi pengerjaan ujian (Fase 3). Dibungkus terpisah dari
// ExamAttemptModel karena banyak field di sini murni UI/lokal (index soal
// aktif, countdown per-detik, status sinkron jawaban) yang TIDAK datang
// dari server dan tidak boleh tercampur dengan model hasil parse response
// API (lihat exam_attempt_model.dart).
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/models/exam_attempt_model.dart';

part 'exam_attempt_state.freezed.dart';

/// Status sinkronisasi 1 jawaban ke server -- dipakai buat indikator kecil
/// di navigator soal (mis. titik abu-abu/hijau/merah), BUKAN untuk blocking
/// navigasi. User harus tetap bisa lanjut/mundur walau sinkron masih
/// berjalan atau gagal; re-tap opsi yang sama akan mencoba sinkron ulang.
enum AnswerSyncStatus { synced, syncing, failed }

@freezed
class LocalAnswer with _$LocalAnswer {
  const factory LocalAnswer({
    int? selectedOptionId,
    String? essayAnswer,
    @Default(AnswerSyncStatus.synced) AnswerSyncStatus syncStatus,
  }) = _LocalAnswer;
}

@freezed
class ExamAttemptSessionState with _$ExamAttemptSessionState {
  const factory ExamAttemptSessionState({
    required ExamAttemptModel attempt,
    required List<ExamQuestion> orderedQuestions,
    @Default(0) int currentIndex,
    @Default(<int, LocalAnswer>{}) Map<int, LocalAnswer> answers,
    required double remainingSeconds,
    @Default(0) int tabSwitchCount,
    @Default(false) bool isFinishing,
    // Diisi begitu finishAttempt() sukses (manual maupun auto-submit saat
    // waktu habis) -- screen mendengar field ini lewat ref.listen untuk
    // trigger navigasi ke halaman ringkasan, bukan lewat return value
    // method (tahan terhadap rebuild widget di tengah proses submit).
    ExamAttemptModel? finishedAttempt,
  }) = _ExamAttemptSessionState;

  const ExamAttemptSessionState._();

  ExamQuestion get currentQuestion => orderedQuestions[currentIndex];
  int get totalQuestions => orderedQuestions.length;

  int get answeredCount => answers.values
      .where((a) =>
          a.selectedOptionId != null || (a.essayAnswer?.trim().isNotEmpty ?? false))
      .length;

  bool get isLastQuestion => currentIndex == totalQuestions - 1;
  bool get isFirstQuestion => currentIndex == 0;
  bool get isTimeUp => remainingSeconds <= 0;
}
EOF_STATE

cat > lib/features/exam_engine/presentation/providers/exam_attempt_provider.dart << 'EOF_PROVIDER'
// lib/features/exam_engine/presentation/providers/exam_attempt_provider.dart
//
// Fase 3: state machine 1 sesi pengerjaan ujian. AsyncNotifier family per
// attemptId (bukan examId -- 1 attempt = 1 sesi; resume otomatis lewat GET
// /exam-attempts/{id} kalau attempt yang sama dibuka ulang, mis. app
// di-kill lalu dibuka lagi selagi status masih in_progress).
//
// Timer dijalankan lokal (Timer.periodic 1 detik) berdasar remaining_seconds
// dari server saat load pertama -- BUKAN polling server tiap detik (hemat
// request, konsisten dengan rate limit endpoint lain di modul ini).
// Konsekuensinya: countdown bisa sedikit drift dari jam server kalau device
// sleep lama; server tetap jadi otoritas final soal waktu habis
// (submitAnswer/finish akan ditolak 422 kalau attempt sudah tidak aktif --
// lihat catatan di ExamRepository.submitAnswer).
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/exam_repository.dart';
import '../../data/models/exam_attempt_model.dart';
import 'exam_attempt_state.dart';

export '../../data/models/exam_attempt_model.dart';
export 'exam_attempt_state.dart';

part 'exam_attempt_provider.g.dart';

@riverpod
class ExamAttemptSession extends _$ExamAttemptSession {
  Timer? _ticker;

  @override
  Future<ExamAttemptSessionState> build(int attemptId) async {
    ref.onDispose(() => _ticker?.cancel());

    final attempt = await ref.read(examRepositoryProvider).getAttempt(attemptId);

    if (!attempt.isInProgress) {
      // Attempt sudah selesai (mis. dibuka ulang dari link/notif lama) --
      // screen yang wajib redirect ke ringkasan, bukan render soal.
      // orderedQuestions sengaja kosong: server memang tidak mengirim
      // questions/question_order kalau bukan in_progress.
      return ExamAttemptSessionState(
        attempt: attempt,
        orderedQuestions: const [],
        remainingSeconds: 0,
        tabSwitchCount: attempt.tabSwitchCount,
        finishedAttempt: attempt,
      );
    }

    final answers = <int, LocalAnswer>{
      for (final a in attempt.answers)
        a.questionId: LocalAnswer(
          selectedOptionId: a.selectedOptionId,
          essayAnswer: a.essayAnswer,
        ),
    };

    _startTicker();

    return ExamAttemptSessionState(
      attempt: attempt,
      orderedQuestions: attempt.orderedQuestions,
      answers: answers,
      remainingSeconds: attempt.remainingSeconds,
      tabSwitchCount: attempt.tabSwitchCount,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = state.valueOrNull;
      if (current == null || current.isFinishing || current.finishedAttempt != null) {
        _ticker?.cancel();
        return;
      }

      final next = current.remainingSeconds - 1;
      if (next <= 0) {
        _ticker?.cancel();
        state = AsyncData(current.copyWith(remainingSeconds: 0));
        // Waktu habis -- auto-submit. Server yang jadi otoritas final soal
        // hasil (status berubah jadi auto_submitted), bukan cuma UI lokal.
        // Sengaja tidak di-await (Timer callback bukan async context) --
        // finish() sendiri sudah menangani error-nya secara internal.
        finish();
        return;
      }
      state = AsyncData(current.copyWith(remainingSeconds: next));
    });
  }

  void goToQuestion(int index) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (index < 0 || index >= current.totalQuestions) return;
    state = AsyncData(current.copyWith(currentIndex: index));
  }

  void nextQuestion() {
    final current = state.valueOrNull;
    if (current == null || current.isLastQuestion) return;
    goToQuestion(current.currentIndex + 1);
  }

  void previousQuestion() {
    final current = state.valueOrNull;
    if (current == null || current.isFirstQuestion) return;
    goToQuestion(current.currentIndex - 1);
  }

  /// Update lokal dulu (UI terasa instan), baru sinkron ke server di
  /// belakang layar. Kalau sinkron gagal, jawaban lokal TETAP dipertahankan
  /// (biar user tidak keblok kerja) tapi ditandai [AnswerSyncStatus.failed]
  /// -- re-tap opsi yang sama akan mencoba sinkron ulang.
  Future<void> selectOption({required int questionId, required int optionId}) async {
    _setLocalAnswer(
      questionId,
      LocalAnswer(selectedOptionId: optionId, syncStatus: AnswerSyncStatus.syncing),
    );
    await _syncAnswer(questionId: questionId, selectedOptionId: optionId);
  }

  /// Dipanggil dari UI dengan debounce (lihat exam_attempt_screen.dart) --
  /// method ini sendiri tidak nge-debounce, supaya tanggung jawab timing
  /// tetap di layer UI yang tahu ritme ketikan user.
  Future<void> setEssayAnswer({required int questionId, required String text}) async {
    _setLocalAnswer(
      questionId,
      LocalAnswer(essayAnswer: text, syncStatus: AnswerSyncStatus.syncing),
    );
    await _syncAnswer(questionId: questionId, essayAnswer: text);
  }

  void _setLocalAnswer(int questionId, LocalAnswer answer) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(answers: {...current.answers, questionId: answer}));
  }

  Future<void> _syncAnswer({
    required int questionId,
    int? selectedOptionId,
    String? essayAnswer,
  }) async {
    try {
      await ref.read(examRepositoryProvider).submitAnswer(
            attemptId: attemptId,
            questionId: questionId,
            selectedOptionId: selectedOptionId,
            essayAnswer: essayAnswer,
          );
      _markSyncStatus(questionId, AnswerSyncStatus.synced);
    } on ApiException {
      // 422 di sini kemungkinan besar waktu habis / attempt sudah tidak
      // aktif -- bukan tanggung jawab method ini untuk redirect (ticker
      // yang pegang otoritas itu lewat finish()), cukup tandai gagal biar
      // kelihatan di UI navigator soal.
      _markSyncStatus(questionId, AnswerSyncStatus.failed);
    }
  }

  void _markSyncStatus(int questionId, AnswerSyncStatus status) {
    final current = state.valueOrNull;
    if (current == null) return;
    final existing = current.answers[questionId];
    if (existing == null) return;
    state = AsyncData(current.copyWith(
      answers: {...current.answers, questionId: existing.copyWith(syncStatus: status)},
    ));
  }

  /// Dipanggil dari screen lewat WidgetsBindingObserver setiap
  /// AppLifecycleState berubah ke paused/inactive (lihat catatan
  /// ExamRepository.reportTabSwitch) -- gagal diam-diam kalau offline,
  /// sengaja tidak mengganggu ujian yang sedang berjalan.
  Future<void> reportTabSwitch() async {
    final count = await ref.read(examRepositoryProvider).reportTabSwitch(attemptId);
    if (count == null) return;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(tabSwitchCount: count));
  }

  /// Submit manual (tombol "Selesai") ATAU auto-submit (waktu habis lewat
  /// ticker). Return null kalau sukses, pesan error kalau gagal -- caller
  /// manual (screen) yang tampilkan snackbar; auto-submit dari ticker
  /// mengabaikan return value ini (errornya sudah cukup tercermin dari
  /// isFinishing balik ke false tanpa finishedAttempt terisi).
  Future<String?> finish() async {
    final current = state.valueOrNull;
    if (current == null || current.isFinishing || current.finishedAttempt != null) {
      return null;
    }

    _ticker?.cancel();
    state = AsyncData(current.copyWith(isFinishing: true));

    try {
      final result = await ref.read(examRepositoryProvider).finishAttempt(attemptId);
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isFinishing: false, finishedAttempt: result));
      return null;
    } on ApiException catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(isFinishing: false));
      return e.message;
    }
  }
}
EOF_PROVIDER

cat > lib/features/exam_engine/presentation/widgets/question_html_text.dart << 'EOF_HTML'
// lib/features/exam_engine/presentation/widgets/question_html_text.dart
//
// Renderer HTML minimal untuk question_text -- cuma menangani tag yang
// TERBUKTI muncul di data asli sejauh ini: <p>, <ol>, <li> (lihat soal id
// 393 di data TIU, "Rata-rata nilai ujian..."). Sengaja TIDAK pakai package
// flutter_html: himpunan tag yang perlu didukung sangat kecil & stabil
// (soal ujian, bukan HTML bebas dari web), jadi parser tangan lebih ringan
// dan tidak menambah dependency (+ resiko versi, tanpa Flutter SDK di
// tangan untuk verifikasi build saat ditulis). Kalau ke depan backend mulai
// kirim tag lain (table, <img> inline di teks, dst), pertimbangkan ganti ke
// flutter_html saat itu baru muncul kebutuhannya nyata.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class QuestionHtmlText extends StatelessWidget {
  const QuestionHtmlText(this.html, {super.key, this.style});

  final String html;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? const TextStyle(color: AppColors.neutral900, fontSize: 15, height: 1.5);

    if (!html.contains('<')) {
      // Fast path: soal biasa (mayoritas data), tanpa tag sama sekali.
      return Text(html, style: baseStyle);
    }

    final blocks = _parseBlocks(html);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: block.isListItem
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 22, child: Text(block.marker ?? '•', style: baseStyle)),
                      Expanded(child: Text(block.text, style: baseStyle)),
                    ],
                  )
                : Text(block.text, style: baseStyle),
          ),
      ],
    );
  }

  List<_HtmlBlock> _parseBlocks(String raw) {
    final blocks = <_HtmlBlock>[];
    var olCounter = 0;
    var inOrderedList = false;

    // Regex sederhana: tangkap tag blok satu per satu (tidak nested) --
    // cukup untuk struktur datar yang muncul di data soal. <ol>/<ul> cuma
    // dipakai sebagai penanda konteks penomoran untuk <li> berikutnya.
    final tagPattern = RegExp(
      r'<p[^>]*>(.*?)</p>|<li[^>]*>(.*?)</li>|<ol[^>]*>|</ol>|<ul[^>]*>|</ul>',
      dotAll: true,
      caseSensitive: false,
    );

    var lastEnd = 0;
    for (final match in tagPattern.allMatches(raw)) {
      // Teks di luar tag yang dikenali (mis. sebelum tag pertama) tetap
      // ditampilkan sebagai paragraf biasa, supaya tidak ada konten hilang
      // diam-diam kalau backend kirim format yang sedikit beda dari dugaan.
      final between = raw.substring(lastEnd, match.start).trim();
      if (between.isNotEmpty) {
        blocks.add(_HtmlBlock(text: _stripTags(between)));
      }
      lastEnd = match.end;

      final full = match.group(0)!;
      if (full.startsWith('<ol')) {
        inOrderedList = true;
        olCounter = 0;
        continue;
      }
      if (full.startsWith('</ol') || full.startsWith('<ul') || full.startsWith('</ul')) {
        if (full.startsWith('</ol')) inOrderedList = false;
        continue;
      }

      if (match.group(1) != null) {
        // <p>...</p>
        final text = _stripTags(match.group(1)!).trim();
        if (text.isNotEmpty) blocks.add(_HtmlBlock(text: text));
      } else if (match.group(2) != null) {
        // <li>...</li>
        final text = _stripTags(match.group(2)!).trim();
        if (text.isEmpty) continue;
        olCounter++;
        blocks.add(_HtmlBlock(
          text: text,
          isListItem: true,
          marker: inOrderedList ? '$olCounter.' : '•',
        ));
      }
    }

    final tail = raw.substring(lastEnd).trim();
    if (tail.isNotEmpty) blocks.add(_HtmlBlock(text: _stripTags(tail)));

    if (blocks.isEmpty) {
      // Fallback terakhir: tag tidak dikenali sama sekali -- tetap
      // tampilkan teksnya (di-strip) daripada kosong.
      blocks.add(_HtmlBlock(text: _stripTags(raw)));
    }

    return blocks;
  }

  String _stripTags(String s) {
    return s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

class _HtmlBlock {
  _HtmlBlock({required this.text, this.isListItem = false, this.marker});
  final String text;
  final bool isListItem;
  final String? marker;
}
EOF_HTML

cat > lib/features/exam_engine/presentation/screens/exam_attempt_screen.dart << 'EOF_SCREEN'
// lib/features/exam_engine/presentation/screens/exam_attempt_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_attempt_provider.dart';
import '../widgets/question_html_text.dart';

class ExamAttemptScreen extends ConsumerStatefulWidget {
  const ExamAttemptScreen({super.key, required this.attemptId});

  final int attemptId;

  @override
  ConsumerState<ExamAttemptScreen> createState() => _ExamAttemptScreenState();
}

class _ExamAttemptScreenState extends ConsumerState<ExamAttemptScreen>
    with WidgetsBindingObserver {
  // Debounce essay ketikan supaya tidak spam POST .../answer tiap huruf --
  // rate limit endpoint itu 60/menit (lihat ExamApiService.submitAnswer).
  Timer? _essayDebounce;
  bool _isFinishingManually = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _essayDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Fire-and-forget sesuai kontrak reportTabSwitch -- tidak mengganggu
      // ujian yang sedang berjalan kalau gagal/offline.
      ref.read(examAttemptSessionProvider(widget.attemptId).notifier).reportTabSwitch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = examAttemptSessionProvider(widget.attemptId);
    final sessionAsync = ref.watch(provider);

    // Begitu attempt selesai (manual atau waktu habis), redirect ke
    // ringkasan ujian. Lewat listener (bukan langsung di build) supaya
    // navigasi hanya terjadi sekali persis saat transisi, bukan tiap
    // rebuild selagi finishedAttempt sudah terisi.
    ref.listen(provider, (previous, next) {
      final prevFinished = previous?.valueOrNull?.finishedAttempt;
      final nextState = next.valueOrNull;
      if (nextState?.finishedAttempt != null && prevFinished == null) {
        final examId = nextState!.finishedAttempt!.examId;
        final isAutoSubmitted =
            nextState.finishedAttempt!.status == ExamAttemptStatus.autoSubmitted;
        if (isAutoSubmitted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Waktu habis -- jawabanmu otomatis disimpan.')),
          );
        }
        if (mounted) context.go('/exams/$examId/summary');
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldExit = await _confirmExit(context);
        if (shouldExit && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: _buildAppBar(sessionAsync.valueOrNull),
        body: sessionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException ? error.message : 'Gagal memuat data ujian',
            onRetry: () => ref.invalidate(provider),
          ),
          data: (session) {
            if (session.finishedAttempt != null) {
              // Redirect sedang diproses lewat ref.listen di atas --
              // tampilkan spinner sebentar daripada layar kosong/soal usang.
              return const Center(child: CircularProgressIndicator());
            }
            return _AttemptBody(
              attemptId: widget.attemptId,
              session: session,
              isFinishingManually: _isFinishingManually,
              onEssayChanged: _handleEssayChanged,
              onTapFinish: _handleTapFinish,
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ExamAttemptSessionState? session) {
    final remaining = session?.remainingSeconds ?? 0;
    final isLowTime = remaining <= 300; // <= 5 menit

    return AppBar(
      backgroundColor: AppColors.neutral50,
      title: session == null
          ? const Text('Ujian Berlangsung')
          : Text('Soal ${session.currentIndex + 1} dari ${session.totalQuestions}'),
      actions: [
        if (session != null) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isLowTime ? AppColors.danger50 : AppColors.brand500.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined,
                    size: 15, color: isLowTime ? AppColors.danger600 : AppColors.brand600),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(remaining),
                  style: TextStyle(
                    color: isLowTime ? AppColors.danger600 : AppColors.brand600,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Navigasi Soal',
            onPressed: () => _openQuestionNavigator(context, session),
          ),
        ],
      ],
    );
  }

  void _handleEssayChanged(int questionId, String text) {
    _essayDebounce?.cancel();
    // Update lokal langsung tanpa tunggu debounce, biar TextField tidak
    // terasa nge-lag -- yang di-debounce cuma panggilan sinkron ke server.
    final notifier = ref.read(examAttemptSessionProvider(widget.attemptId).notifier);
    _essayDebounce = Timer(const Duration(milliseconds: 800), () {
      notifier.setEssayAnswer(questionId: questionId, text: text);
    });
  }

  Future<void> _handleTapFinish(ExamAttemptSessionState session) async {
    final unanswered = session.totalQuestions - session.answeredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selesaikan Ujian?'),
        content: Text(
          unanswered > 0
              ? 'Masih ada $unanswered soal yang belum kamu jawab. Yakin ingin menyelesaikan ujian sekarang?'
              : 'Semua ${session.totalQuestions} soal sudah dijawab. Yakin ingin menyelesaikan ujian sekarang?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Selesaikan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isFinishingManually = true);
    final error =
        await ref.read(examAttemptSessionProvider(widget.attemptId).notifier).finish();
    if (!mounted) return;
    setState(() => _isFinishingManually = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    // Kalau sukses, navigasi ditangani ref.listen di build() begitu
    // finishedAttempt terisi -- tidak perlu apa-apa lagi di sini.
  }

  Future<bool> _confirmExit(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Ujian?'),
        content: const Text(
          'Ujian tetap berjalan (waktu terus berkurang di server). Kamu bisa lanjutkan lagi '
          'lewat menu ujian ini selama status masih berlangsung.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _openQuestionNavigator(BuildContext context, ExamAttemptSessionState session) {
    final notifier = ref.read(examAttemptSessionProvider(widget.attemptId).notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _QuestionNavigatorSheet(
        session: session,
        onSelect: (index) {
          notifier.goToQuestion(index);
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  static String _formatDuration(double seconds) {
    final total = seconds.floor().clamp(0, 999999);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }
}

class _AttemptBody extends ConsumerWidget {
  const _AttemptBody({
    required this.attemptId,
    required this.session,
    required this.isFinishingManually,
    required this.onEssayChanged,
    required this.onTapFinish,
  });

  final int attemptId;
  final ExamAttemptSessionState session;
  final bool isFinishingManually;
  final void Function(int questionId, String text) onEssayChanged;
  final Future<void> Function(ExamAttemptSessionState session) onTapFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final question = session.currentQuestion;
    final answer = session.answers[question.id];
    final notifier = ref.read(examAttemptSessionProvider(attemptId).notifier);

    return Column(
      children: [
        LinearProgressIndicator(
          value: session.totalQuestions == 0
              ? 0
              : (session.currentIndex + 1) / session.totalQuestions,
          backgroundColor: AppColors.neutral200,
          color: AppColors.brand500,
          minHeight: 3,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.category!.code,
                      style: const TextStyle(
                        color: AppColors.brand600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                QuestionHtmlText(question.questionText),
                if (question.mediaType == 'image' && question.mediaUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      question.mediaUrl!,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (question.isEssay)
                  _EssayField(
                    key: ValueKey(question.id),
                    initialText: answer?.essayAnswer ?? '',
                    onChanged: (text) => onEssayChanged(question.id, text),
                  )
                else
                  for (final option in question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OptionCard(
                        option: option,
                        isSelected: answer?.selectedOptionId == option.id,
                        onTap: () =>
                            notifier.selectOption(questionId: question.id, optionId: option.id),
                      ),
                    ),
              ],
            ),
          ),
        ),
        _BottomNavBar(
          session: session,
          isFinishing: isFinishingManually || session.isFinishing,
          onPrevious: notifier.previousQuestion,
          onNext: notifier.nextQuestion,
          onFinish: () => onTapFinish(session),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option, required this.isSelected, required this.onTap});

  final ExamOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brand500 : AppColors.neutral200,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: isSelected ? AppColors.brand500 : AppColors.neutral400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                option.optionText,
                style: TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EssayField extends StatefulWidget {
  const _EssayField({super.key, required this.initialText, required this.onChanged});

  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_EssayField> createState() => _EssayFieldState();
}

class _EssayFieldState extends State<_EssayField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: 8,
      minLines: 5,
      onChanged: widget.onChanged,
      decoration: const InputDecoration(hintText: 'Tulis jawabanmu di sini...'),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.session,
    required this.isFinishing,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
  });

  final ExamAttemptSessionState session;
  final bool isFinishing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            OutlinedButton(
              onPressed: session.isFirstQuestion ? null : onPrevious,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: session.isLastQuestion
                  ? FilledButton(
                      onPressed: isFinishing ? null : onFinish,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: isFinishing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Selesai'),
                    )
                  : FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Selanjutnya'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionNavigatorSheet extends StatelessWidget {
  const _QuestionNavigatorSheet({required this.session, required this.onSelect});

  final ExamAttemptSessionState session;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.answeredCount} dari ${session.totalQuestions} soal terjawab',
              style: const TextStyle(
                color: AppColors.neutral900,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: GridView.builder(
                itemCount: session.totalQuestions,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final question = session.orderedQuestions[index];
                  final answer = session.answers[question.id];
                  final isAnswered = answer?.selectedOptionId != null ||
                      (answer?.essayAnswer?.trim().isNotEmpty ?? false);
                  final isCurrent = index == session.currentIndex;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.brand500
                            : isAnswered
                                ? AppColors.brand50
                                : AppColors.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent ? AppColors.brand500 : AppColors.neutral200,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : AppColors.neutral900,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
EOF_SCREEN

cat > lib/core/router/app_router.dart << 'EOF_ROUTER'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_form_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/akun/presentation/screens/edit_profil_screen.dart';
import '../../features/akun/presentation/screens/ganti_password_screen.dart';
import '../../features/enrollment/presentation/screens/paket_saya_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/register/form' ||
          loc == '/check-email' ||
          loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash) return '/login';
          if (isAuthRoute) return null;
          return '/login';
        },
        authenticated: (_) {
          if (isSplash || isAuthRoute) return '/home';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/register/form',
        builder: (_, __) => const RegisterFormScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/akun/edit-profil',
        builder: (_, __) => const EditProfilScreen(),
      ),
      GoRoute(
        path: '/akun/ganti-password',
        builder: (_, __) => const GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
      ),
      GoRoute(
        path: '/paket/:packageId/exams',
        builder: (context, state) {
          final packageId = int.parse(state.pathParameters['packageId']!);
          return ExamListScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/exams/:examId/summary',
        builder: (context, state) {
          final examId = int.parse(state.pathParameters['examId']!);
          return ExamSummaryScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamAttemptScreen(attemptId: attemptId);
        },
      ),
    ],
  );
}
EOF_ROUTER

cat > lib/features/exam_engine/presentation/screens/exam_summary_screen.dart << 'EOF_SUMMARY'
// lib/features/exam_engine/presentation/screens/exam_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/exam_repository.dart';
import '../providers/exam_provider.dart';

class ExamSummaryScreen extends ConsumerWidget {
  const ExamSummaryScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(examSummaryProvider(examId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Ringkasan Ujian'),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat ringkasan ujian',
          onRetry: () => ref.invalidate(examSummaryProvider(examId)),
        ),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(examSummaryProvider(examId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _ExamInfoCard(summary: summary),
              if (summary.hasBeenAttempted) ...[
                const SizedBox(height: 20),
                const _SectionTitle(title: 'Percobaan Pertama'),
                const SizedBox(height: 10),
                _AttemptCard(attempt: summary.firstAttempt!),
                if (summary.latestAttempt != null &&
                    summary.latestAttempt!.attemptId != summary.firstAttempt!.attemptId) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'Percobaan Terakhir'),
                  const SizedBox(height: 10),
                  _AttemptCard(attempt: summary.latestAttempt!),
                ],
              ],
              const SizedBox(height: 24),
              _StartButton(summary: summary, examId: examId),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamInfoCard extends StatelessWidget {
  const _ExamInfoCard({required this.summary});
  final ExamSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final exam = summary.exam;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exam.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Text(
                '${exam.durationMinutes} menit',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.repeat, color: Colors.white70, size: 15),
              const SizedBox(width: 4),
              Text(
                '${summary.attemptsCount} kali dikerjakan',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
          if (exam.sections.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final section in exam.sections)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      section.code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.neutral900,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt});
  final ExamAttemptSummary attempt;

  @override
  Widget build(BuildContext context) {
    final passed = attempt.passed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                attempt.score.toStringAsFixed(0),
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: passed ? AppColors.success50 : AppColors.danger50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  passed ? 'Lulus' : 'Belum Lulus',
                  style: TextStyle(
                    color: passed ? AppColors.success700 : AppColors.danger600,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final section in attempt.sections)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    section.name,
                    style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                  ),
                  Text(
                    section.rawScore.toStringAsFixed(0),
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StartButton extends ConsumerStatefulWidget {
  const _StartButton({required this.summary, required this.examId});
  final ExamSummaryModel summary;
  final int examId;

  @override
  ConsumerState<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<_StartButton> {
  bool _isStarting = false;

  Future<void> _handleStart() async {
    setState(() => _isStarting = true);

    try {
      final attempt = await ref.read(examRepositoryProvider).startExam(examId: widget.examId);

      if (!mounted) return;
      // Attempt in_progress untuk kombinasi exam+batch+bank yang sama
      // di-resume otomatis oleh server (lihat catatan ExamApiService.startExam),
      // jadi ini juga jalan buat kasus "Lanjutkan" -- bukan cuma "Mulai Ujian".
      context.push('/exam-attempts/${attempt.id}');
    } on ApiException catch (e) {
      if (!mounted) return;
      String message = e.message;
      if (e.isPreviousPartIncomplete) {
        message = 'Selesaikan part sebelumnya dulu sebelum mengerjakan ini.';
      } else if (e.isValidationError && (e.batchStartAt != null || e.batchEndAt != null)) {
        message = 'Try-out belum buka atau sudah tutup (batch: '
            '${e.batchStartAt ?? '-'} s.d. ${e.batchEndAt ?? '-'}).';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasInProgress = widget.summary.hasInProgressAttempt;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isStarting ? null : _handleStart,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isStarting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(hasInProgress ? 'Lanjutkan' : 'Mulai Ujian'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
EOF_SUMMARY

echo 'Semua file Fase 3 ditulis.'
