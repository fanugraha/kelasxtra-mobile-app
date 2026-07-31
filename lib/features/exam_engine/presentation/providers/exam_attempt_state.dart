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
    // "Ragu-ragu" -- murni penanda lokal buat bantu user, TIDAK dikirim ke
    // server (endpoint .../answer cuma terima question_id + jawaban).
    @Default(false) bool isFlagged,
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
    // Countdown section aktif -- cuma dipakai kalau attempt.usesSectionTimers
    // == true. Null berarti exam ini tidak pakai timer per-section (kasus
    // paling umum di data yang sudah ditest), UI dual-timer di appbar harus
    // guard lewat null-check ini, bukan cuma usesSectionTimers, karena
    // section timer bisa sementara null selagi resync ke server berjalan.
    double? sectionRemainingSeconds,
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
  bool get hasSectionTimer => attempt.usesSectionTimers && sectionRemainingSeconds != null;
}
