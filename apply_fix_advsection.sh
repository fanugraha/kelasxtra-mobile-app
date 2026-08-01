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
import 'dart:collection';

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
  bool _isAdvancingSection = false;

  // Throttle POST .../answer -- endpoint dibatasi 60/menit di server.
  // Interval 1100ms (~54/menit) kasih margin aman, bukan pas di batas.
  // Antrian isinya questionId (bukan payload) supaya kalau user ganti
  // jawaban beberapa kali sebelum request sebelumnya sempat jalan, yang
  // terkirim SELALU state jawaban paling baru dari `state.answers` saat
  // giliran id itu tiba -- bukan numpuk semua perubahan versi lama.
  final Queue<int> _syncQueue = Queue<int>();
  Timer? _queueDispatcher;
  static const _minSyncInterval = Duration(milliseconds: 1100);

  @override
  Future<ExamAttemptSessionState> build(int attemptId) async {
    ref.onDispose(() {
      _ticker?.cancel();
      _queueDispatcher?.cancel();
    });

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
      sectionRemainingSeconds:
          attempt.usesSectionTimers ? attempt.currentSection?.remainingSeconds : null,
      tabSwitchCount: attempt.tabSwitchCount,
    );
  }

  /// Timer tunggal yang jalan tiap detik, ngurus DUA countdown sekaligus
  /// kalau attempt.usesSectionTimers == true: total (remainingSeconds) dan
  /// section aktif (sectionRemainingSeconds). Keduanya independen -- habis
  /// duluan yang mana pun bisa terjadi:
  /// - Total habis duluan -> auto-submit seluruh attempt (perilaku lama).
  /// - Section habis duluan -> TIDAK auto-submit attempt, cuma pindah ke
  ///   section berikutnya. Client sendiri tidak tahu urutan/section
  ///   berikutnya (itu ditentukan server) jadi begitu section timer lokal
  ///   mencapai 0, panggil ulang GET /exam-attempts/{id} buat ambil
  ///   current_section terbaru dan reset countdown section dari situ.
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

      if (current.hasSectionTimer) {
        final nextSection = current.sectionRemainingSeconds! - 1;
        if (nextSection <= 0) {
          state = AsyncData(current.copyWith(
            remainingSeconds: next,
            sectionRemainingSeconds: 0,
          ));
          // Guard _isAdvancingSection -- tanpa ini, tiap tick selagi
          // sectionRemainingSeconds masih 0 (nunggu response GET atau
          // retry offline) akan memicu _advanceSection lagi dan lagi,
          // numpuk beberapa request paralel buat hal yang sama.
          if (!_isAdvancingSection) {
            _isAdvancingSection = true;
            _advanceSection();
          }
          return;
        }
        state = AsyncData(current.copyWith(
          remainingSeconds: next,
          sectionRemainingSeconds: nextSection,
        ));
        return;
      }

      state = AsyncData(current.copyWith(remainingSeconds: next));
    });
  }

  /// Dipanggil begitu countdown section lokal mencapai 0. Server yang
  /// menentukan section berikutnya (nama, urutan, durasi) -- client cuma
  /// GET ulang attempt dan ambil current_section yang baru. Kalau ternyata
  /// section yang habis itu section TERAKHIR, server akan mengubah status
  /// attempt jadi selesai (sama seperti waktu total habis) -- makanya di
  /// sini juga guard lewat isInProgress, konsisten dengan _resyncAttemptStatus.
  Future<void> _advanceSection() async {
    final current = state.valueOrNull;
    if (current == null || current.finishedAttempt != null) {
      _isAdvancingSection = false;
      return;
    }
    try {
      final fresh = await ref.read(examRepositoryProvider).getAttempt(attemptId);
      final latest = state.valueOrNull ?? current;
      if (!fresh.isInProgress) {
        _ticker?.cancel();
        state = AsyncData(latest.copyWith(finishedAttempt: fresh));
        _isAdvancingSection = false;
        return;
      }
      state = AsyncData(latest.copyWith(
        attempt: fresh,
        // BUG FIX: sebelumnya orderedQuestions/currentIndex tidak ikut
        // di-update di sini -- attempt sudah pindah ke section baru tapi
        // soal yang dirender tetap soal section lama (dan kalau section
        // baru lebih pendek, currentIndex lama bisa out-of-range ->
        // RangeError di currentQuestion getter). orderedQuestions HARUS
        // diturunkan ulang dari fresh (bukan dari latest) karena
        // question_order/questions section baru datang dari fresh.
        // currentIndex direset ke 0 -- urutan soal section baru tidak
        // related sama sekali ke posisi terakhir di section lama.
        orderedQuestions: fresh.orderedQuestions,
        currentIndex: 0,
        sectionRemainingSeconds: fresh.usesSectionTimers
            ? (fresh.currentSection?.remainingSeconds ?? 0)
            : null,
      ));
      _isAdvancingSection = false;
    } on ApiException {
      // Gagal (mis. offline) -- biarkan section timer diam di 0, retry
      // sekali lagi 1 detik kemudian. Total timer (remainingSeconds) tetap
      // jalan normal karena tidak tergantung ini. _isAdvancingSection
      // TETAP true selama retry ini menunggu, biar tick reguler tidak ikut
      // memicu panggilan paralel lain.
      Timer(const Duration(seconds: 1), () {
        _isAdvancingSection = false;
        _advanceSection();
      });
    }
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

  /// Update lokal dulu (UI terasa instan), baru ANTRE untuk sinkron ke
  /// server (lihat _enqueueSync) -- tidak fire langsung supaya klik cepat
  /// beruntun (mis. swipe cepat + auto-select, atau ganti-ganti opsi) tidak
  /// nabrak rate limit 60/menit endpoint .../answer.
  void selectOption({required int questionId, required int optionId}) {
    _updateLocalAnswer(
      questionId,
      (existing) => (existing ?? const LocalAnswer()).copyWith(
        selectedOptionId: optionId,
        syncStatus: AnswerSyncStatus.syncing,
      ),
    );
    _enqueueSync(questionId);
  }

  /// Dipanggil dari UI dengan debounce (lihat exam_attempt_screen.dart) --
  /// method ini sendiri tidak nge-debounce, supaya tanggung jawab timing
  /// ketikan tetap di layer UI. Debounce essay + antrian throttle di sini
  /// jalan berlapis: debounce ngurangin FREKUENSI enqueue, antrian ngatur
  /// JEDA antar request yang benar-benar keluar ke server.
  void setEssayAnswer({required int questionId, required String text}) {
    _updateLocalAnswer(
      questionId,
      (existing) => (existing ?? const LocalAnswer()).copyWith(
        essayAnswer: text,
        syncStatus: AnswerSyncStatus.syncing,
      ),
    );
    _enqueueSync(questionId);
  }

  /// Toggle penanda "ragu-ragu" -- murni lokal, tidak memicu sinkron ke
  /// server sama sekali (tidak ada field untuk ini di endpoint .../answer).
  void toggleFlag(int questionId) {
    _updateLocalAnswer(
      questionId,
      (existing) => (existing ?? const LocalAnswer()).copyWith(
        isFlagged: !(existing?.isFlagged ?? false),
      ),
    );
  }

  void _updateLocalAnswer(int questionId, LocalAnswer Function(LocalAnswer?) update) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = update(current.answers[questionId]);
    state = AsyncData(current.copyWith(answers: {...current.answers, questionId: next}));
  }

  /// Masukkan questionId ke antrian sinkron kalau belum ada di situ (kalau
  /// sudah ada, tidak perlu duplikat -- saat gilirannya tiba, dispatcher
  /// akan baca jawaban TERBARU dari state, bukan snapshot lama). Mulai
  /// dispatcher kalau belum jalan.
  void _enqueueSync(int questionId) {
    if (!_syncQueue.contains(questionId)) _syncQueue.add(questionId);
    _queueDispatcher ??= Timer(Duration.zero, _dispatchNext);
  }

  /// Proses satu item antrian, lalu jadwalkan pemrosesan berikutnya setelah
  /// [_minSyncInterval] -- baik antrian masih ada isinya atau tidak
  /// (kalau kosong, _dispatchNext berikutnya cuma langsung berhenti dan
  /// set _queueDispatcher = null, siap dipicu lagi oleh enqueue berikutnya).
  void _dispatchNext() {
    if (_syncQueue.isEmpty) {
      _queueDispatcher = null;
      return;
    }
    final questionId = _syncQueue.removeFirst();
    // Fire-and-forget sengaja -- dispatcher tidak boleh nunggu network,
    // errornya sudah ditangani penuh di dalam _syncAnswerForQuestion.
    _syncAnswerForQuestion(questionId);
    _queueDispatcher = Timer(_minSyncInterval, _dispatchNext);
  }

  Future<void> _syncAnswerForQuestion(int questionId) async {
    final current = state.valueOrNull;
    final answer = current?.answers[questionId];
    if (current == null || answer == null) return;

    try {
      await ref.read(examRepositoryProvider).submitAnswer(
            attemptId: attemptId,
            questionId: questionId,
            selectedOptionId: answer.selectedOptionId,
            essayAnswer: answer.essayAnswer,
          );
      _markSyncStatus(questionId, AnswerSyncStatus.synced);
    } on ApiException catch (e) {
      _markSyncStatus(questionId, AnswerSyncStatus.failed);
      if (e.isValidationError) {
        // Endpoint ini cuma terima question_id + selected_option_id/
        // essay_answer -- hampir tidak mungkin gagal validasi kalau
        // attempt masih in_progress. 422 di sini kemungkinan besar berarti
        // waktu sudah habis di server (device sleep lama, ticker lokal
        // belum sempat mencapai 0) atau attempt sudah di-finish dari
        // device lain. Re-cek status ke server supaya UI tidak nyangkut
        // di soal yang sudah basi sampai ticker lokal sendiri habis.
        await _resyncAttemptStatus();
      }
    }
  }

  /// Cek ulang status attempt ke server dan set [finishedAttempt] kalau
  /// ternyata sudah tidak in_progress lagi -- screen dengar field ini
  /// lewat ref.listen untuk redirect. Gagal diam-diam kalau offline
  /// (mis. tidak ada koneksi pas dipanggil) -- ticker lokal tetap jadi
  /// fallback biasa begitu remaining_seconds mencapai 0.
  Future<void> _resyncAttemptStatus() async {
    final current = state.valueOrNull;
    if (current == null || current.finishedAttempt != null) return;
    try {
      final fresh = await ref.read(examRepositoryProvider).getAttempt(attemptId);
      if (!fresh.isInProgress) {
        _ticker?.cancel();
        final latest = state.valueOrNull ?? current;
        state = AsyncData(latest.copyWith(finishedAttempt: fresh));
      }
    } on ApiException {
      // Biarkan -- lihat catatan di atas.
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
    _queueDispatcher?.cancel();
    _queueDispatcher = null;
    _syncQueue.clear();
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

echo 'Bug fix _advanceSection (orderedQuestions/currentIndex sync) diterapkan.'
