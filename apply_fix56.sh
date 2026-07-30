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
        final finished = nextState!.finishedAttempt!;
        final examId = finished.examId;

        if (mounted) {
          // graded: langsung ada skor final, tidak perlu pesan tambahan --
          // ringkasan yang dituju sudah cukup jelas. submitted: masih ada
          // essay nunggu dinilai tutor, skor BELUM final -- kasih tahu
          // biar user tidak bingung kenapa skornya belum muncul/berubah.
          // auto_submitted: waktu habis, bukan aksi user sendiri.
          final message = switch (finished.status) {
            ExamAttemptStatus.autoSubmitted =>
              'Waktu habis -- jawabanmu otomatis disimpan.',
            ExamAttemptStatus.submitted =>
              'Jawaban essay kamu sedang dinilai tutor. Skor final akan muncul setelah penilaian selesai.',
            _ => null,
          };
          if (message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
            );
          }
        }

        // Belum ada screen review terpisah (Fase 5) -- baik graded maupun
        // submitted untuk sekarang sama-sama diarahkan ke ringkasan exam;
        // ExamSummaryScreen sudah menampilkan skor dari attempt terakhir
        // begitu status-nya graded. Kalau masih submitted, skor lama
        // (percobaan sebelumnya, kalau ada) yang tampil dulu -- bukan bug,
        // cuma keterbatasan sampai halaman review dibangun.
        if (mounted) context.go('/exams/$examId/summary');
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
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

cat > lib/features/beranda/presentation/screens/beranda_screen.dart << 'EOF_BERANDA'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/beranda_provider.dart';

class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: berandaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            onRetry: () => ref.read(berandaNotifierProvider.notifier).refresh(),
          ),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.read(berandaNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _HeaderRow(
                  userName: data.userName,
                  streakDays: data.streakDays,
                  hasActiveSubscription: data.hasActiveSubscription,
                  subscriptionPackageName: data.subscriptionPackageName,
                  unreadNotificationCount: data.unreadNotificationCount,
                ),
                const SizedBox(height: 24),
                _ContinueCard(exam: data.continueExam),
                if (data.promoBanners.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _PromoCarousel(banners: data.promoBanners),
                ],
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Latihan & Try Out'),
                const SizedBox(height: 12),
                const _PracticeGrid(),
                if (data.recommendedPackages.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Rekomendasi Paket'),
                  const SizedBox(height: 12),
                  _RecommendedPackages(packages: data.recommendedPackages),
                ],
                const SizedBox(height: 28),
                _StatsRow(averageScore: data.averageScore, rank: data.rank),
                const SizedBox(height: 20),
                _LeaderboardPreview(rank: data.rank),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({
    required this.userName,
    required this.streakDays,
    required this.hasActiveSubscription,
    required this.subscriptionPackageName,
    required this.unreadNotificationCount,
  });

  final String userName;
  final int streakDays;
  final bool hasActiveSubscription;
  final String? subscriptionPackageName;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brand500,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Halo,',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                  ),
                  if (hasActiveSubscription) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.gold100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subscriptionPackageName ?? 'Premium',
                        style: const TextStyle(
                          color: AppColors.gold600,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (streakDays > 0) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.local_fire_department, color: AppColors.danger600, size: 15),
                    const SizedBox(width: 2),
                    Text(
                      '$streakDays',
                      style: const TextStyle(
                        color: AppColors.danger600,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_none_outlined, color: AppColors.neutral600),
            ),
            if (unreadNotificationCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.danger600,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.exam});
  final ContinueExamData? exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasExam = exam != null;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasExam ? Icons.play_circle_outline : Icons.bolt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                hasExam ? 'Lanjutkan Belajar' : 'Mulai Belajar',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasExam ? exam!.title : 'Belum ada latihan hari ini',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasExam) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: exam!.progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(exam!.progress * 100).round()}% selesai',
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // hasExam -> examId dari ContinueExamData sudah cukup untuk
              // masuk ke screen ringkasan exam (Fase 2), yang lalu push ke
              // exam-taking UI (Fase 3) begitu attempt dibuat/di-resume.
              // !hasExam -> belum ada exam untuk dilanjutkan sama sekali,
              // tetap arahkan ke tab Latihan seperti sebelumnya.
              onPressed: () {
                if (hasExam) {
                  context.push('/exams/${exam!.examId}/summary');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur ini segera hadir. Sementara, cek Latihan.')),
                  );
                  ref.read(selectedTabIndexProvider.notifier).state = 1;
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.brand700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(hasExam ? 'Lanjutkan' : 'Cari Latihan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carousel promo dari /promos/active. Ganti posisi banner upsell lama --
/// satu CTA utama saja sesuai prinsip yang disepakati (bukan tumpuk-tumpuk
/// promo + banner subscription sekaligus). Status subscription sekarang
/// cukup lewat badge kecil di header (_HeaderRow), bukan banner terpisah.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.banners});
  final List<PromoBanner> banners;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gold600.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold600.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gold600.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.local_offer_outlined, color: AppColors.gold600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  banner.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.neutral900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.danger50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  banner.discountLabel,
                                  style: const TextStyle(
                                    color: AppColors.danger600,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kode: ${banner.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gold600,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.neutral400),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.brand500 : AppColors.neutral200,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
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
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Grid 2x2 akses cepat. 3 item pertama pindah ke tab Latihan (index 1 di
/// AppShell) -- LatihanScreen saat ini masih placeholder ("segera hadir"),
/// jadi semua 3 akan mendarat di tempat yang sama untuk saat ini. Itu
/// bukan dead button (tab-nya nyata & merespons), cuma isinya belum
/// didesain -- akan otomatis benar begitu LatihanScreen dibangun dengan
/// section internal.
///
/// "Analisis Performa" belum ada halamannya sama sekali -- BerandaData
/// belum punya data breakdown performa yang cukup (baru averageScore/rank
/// flat, belum ranking.percentile/totalParticipants/program). Sementara
/// tampilkan SnackBar sampai model & halamannya dibangun.
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  static const _items = [
    (icon: Icons.topic_outlined, title: 'Latihan Soal per Topik', subtitle: 'Susun roadmap topik'),
    (icon: Icons.center_focus_strong_outlined, title: 'Latihan Fokus', subtitle: 'Perkuat kelemahanmu'),
    (icon: Icons.timer_outlined, title: 'Tryout', subtitle: 'Simulasi CAT penuh'),
    (icon: Icons.insights_outlined, title: 'Analisis Performa', subtitle: 'Lihat progres belajarmu'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: _items.map((item) {
        final isPerformance = item.title == 'Analisis Performa';
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isPerformance) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analisis Performa segera hadir')),
              );
            } else {
              ref.read(selectedTabIndexProvider.notifier).state = 1;
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.brand500, size: 22),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Format angka jadi "Rp20.000" (titik sebagai pemisah ribuan, tanpa
/// desimal -- harga selalu bulat rupiah di sini).
String _formatRupiah(double value) {
  final digits = value.round().toString().split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && i % 3 == 0) grouped.add('.');
    grouped.add(digits[i]);
  }
  return 'Rp${grouped.reversed.join()}';
}

/// Bentuk pita diskon bergaya e-commerce (flag/notch di sisi kanan) --
/// dipakai di pojok kiri-atas gambar card paket, mirip badge "-50%" di
/// Shopee/Tokopedia.
class _DiscountRibbon extends StatelessWidget {
  const _DiscountRibbon({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        color: AppColors.danger600,
        padding: const EdgeInsets.only(left: 8, right: 12, top: 4, bottom: 4),
        child: Text(
          '-$label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final notch = 7.0;
    return Path()
      ..lineTo(0, size.height)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - notch, 0)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Chip kecil hijau bergaya "Gratis Ongkir"-nya Shopee -- dipakai buat
/// menonjolkan 1 fitur unggulan paket di card.
class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success600.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.success600.withOpacity(0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.success600,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Section baru -- recommendedPackages sudah lama di-fetch tapi cuma
/// dipakai buat hitung discountLabel di banner lama. Sekarang ditampilkan
/// sebagai card gaya marketplace (Shopee-like): gambar persegi dengan
/// pita diskon, harga besar + harga asli dicoret + chip persen, dan chip
/// fitur unggulan.
class _RecommendedPackages extends StatelessWidget {
  const _RecommendedPackages({required this.packages});
  final List<RecommendedPackage> packages;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final package = packages[index];
          final hasDiscount = package.discountLabel != null;
          final features = package.features ?? const <String>[];

          return Container(
            width: 168,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutral200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: package.bannerImageUrl != null
                          ? Image.network(
                              package.bannerImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: AppColors.neutral100),
                            )
                          : Container(
                              color: AppColors.neutral100,
                              alignment: Alignment.center,
                              child: const Icon(Icons.school_outlined, color: AppColors.neutral400),
                            ),
                    ),
                    if (hasDiscount)
                      Positioned(
                        top: 8,
                        left: 0,
                        child: _DiscountRibbon(label: package.discountLabel!),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutral900,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatRupiah(package.discountPrice ?? package.price),
                        style: const TextStyle(
                          color: AppColors.danger600,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatRupiah(package.price),
                              style: const TextStyle(
                                color: AppColors.neutral400,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.danger50,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: AppColors.danger600.withOpacity(0.4)),
                              ),
                              child: Text(
                                package.discountLabel!,
                                style: const TextStyle(
                                  color: AppColors.danger600,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _FeatureChip(label: features.first),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Disederhanakan jadi 2 kolom -- Streak pindah ke header (mini, gaya
/// Duolingo), jadi tidak perlu diulang di sini.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.averageScore, required this.rank});

  final double averageScore;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.insights_outlined,
            iconColor: AppColors.success600,
            label: 'Skor Rata-rata',
            value: averageScore > 0 ? averageScore.toStringAsFixed(0) : '-',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.emoji_events_outlined,
            iconColor: AppColors.gold600,
            label: 'Peringkat',
            value: rank > 0 ? '#$rank' : '-',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardPreview extends ConsumerWidget {
  const _LeaderboardPreview({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sebelumnya kartu ini punya ikon chevron (menyiratkan bisa di-tap)
    // tapi tidak ada onTap sama sekali -- ditambahkan supaya benar-benar
    // membawa user ke tab Peringkat, bukan dead UI.
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 2,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.gold600.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.leaderboard_outlined, color: AppColors.gold600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank > 0 ? 'Kamu peringkat #$rank minggu ini' : 'Belum masuk peringkat',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Lihat papan peringkat lengkap',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.neutral400),
        ],
      ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
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
            const Text(
              'Gagal memuat beranda',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
EOF_BERANDA

echo 'Fix #5 (auto-redirect attempt basi) + #6 (bedakan graded/submitted) diterapkan.'
