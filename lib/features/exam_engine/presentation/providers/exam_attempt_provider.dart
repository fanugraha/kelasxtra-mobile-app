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
