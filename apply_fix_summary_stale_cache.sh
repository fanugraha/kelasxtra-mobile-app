#!/usr/bin/env bash
# apply_fix_summary_stale_cache.sh
# Fix: skor/riwayat percobaan tidak muncul di Ringkasan Ujian setelah
# selesai ujian, karena examSummaryProvider(examId) tidak di-invalidate
# sebelum redirect balik ke summary -- data lama (dari sebelum attempt
# selesai) yang ke-cache Riverpod yang tampil, bukan data terbaru server.
# Jalankan dari root repo kelasxtra-mobile-app.
set -euo pipefail

cat > "lib/features/exam_engine/presentation/screens/exam_attempt_screen.dart" << 'DART_EOF'
// lib/features/exam_engine/presentation/screens/exam_attempt_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_attempt_provider.dart';
import '../providers/exam_provider.dart';
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

  // Satu PageController buat swipe antar soal (item #3). Perpindahan
  // currentIndex bisa datang dari 2 arah: swipe manual (onPageChanged ->
  // panggil notifier.goToQuestion) ATAU dari luar PageView (tombol
  // Sebelumnya/Selanjutnya, tap grid navigator) -- untuk arah kedua,
  // controller perlu di-jumpToPage manual, disinkronkan tiap build lewat
  // _syncPageController (bukan langsung di build supaya tidak motret
  // PageView selagi masih dalam proses layout).
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _essayDebounce?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncPageController(int targetIndex) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      final currentPage = _pageController.page?.round() ?? _pageController.initialPage;
      if (currentPage != targetIndex) {
        _pageController.jumpToPage(targetIndex);
      }
    });
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
        //
        // BUG YANG DIPERBAIKI: examSummaryProvider(examId) kemungkinan
        // besar sudah pernah di-watch sebelumnya (screen ringkasan dibuka
        // dulu buat tombol "Mulai Ujian"), jadi hasilnya masih ke-cache
        // dengan attempts_count/skor LAMA (dari sebelum attempt ini
        // selesai). Tanpa invalidate ini, ringkasan yang muncul setelah
        // selesai ujian bisa nampilin "0 kali dikerjakan" / tanpa kartu
        // skor sama sekali walau attempt-nya sudah graded di server.
        ref.invalidate(examSummaryProvider(examId));
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
            _syncPageController(session.currentIndex);
            return _AttemptBody(
              attemptId: widget.attemptId,
              session: session,
              pageController: _pageController,
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
    final hasSectionTimer = session?.hasSectionTimer ?? false;

    return AppBar(
      backgroundColor: AppColors.neutral50,
      title: session == null
          ? const Text('Ujian Berlangsung')
          : Text('Soal ${session.currentIndex + 1} dari ${session.totalQuestions}'),
      actions: [
        if (session != null) ...[
          if (hasSectionTimer)
            // Timer section aktif -- ditampilkan TERPISAH dari timer total
            // di sebelahnya, keduanya berjalan independen (lihat catatan
            // dual-timer di exam_attempt_provider.dart). Section habis
            // duluan tidak menghentikan ujian, cuma pindah section.
            _TimerChip(
              icon: Icons.view_agenda_outlined,
              label: session.attempt.currentSection?.name ?? 'Sesi',
              seconds: session.sectionRemainingSeconds!,
              isLowTime: session.sectionRemainingSeconds! <= 60,
            ),
          _TimerChip(
            icon: Icons.timer_outlined,
            seconds: remaining,
            isLowTime: isLowTime,
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
}

String _formatDuration(double seconds) {
  final total = seconds.floor().clamp(0, 999999);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({
    required this.icon,
    required this.seconds,
    required this.isLowTime,
    this.label,
  });

  final IconData icon;
  final double seconds;
  final bool isLowTime;
  // Nama section (kalau ini timer section) -- ditampilkan sebelum angka
  // biar user tahu ini countdown apa saat 2 chip tampil berdampingan.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Icon(icon, size: 15, color: isLowTime ? AppColors.danger600 : AppColors.brand600),
          const SizedBox(width: 4),
          Text(
            label == null ? _formatDuration(seconds) : '$label ${_formatDuration(seconds)}',
            style: TextStyle(
              color: isLowTime ? AppColors.danger600 : AppColors.brand600,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptBody extends ConsumerWidget {
  const _AttemptBody({
    required this.attemptId,
    required this.session,
    required this.pageController,
    required this.isFinishingManually,
    required this.onEssayChanged,
    required this.onTapFinish,
  });

  final int attemptId;
  final ExamAttemptSessionState session;
  final PageController pageController;
  final bool isFinishingManually;
  final void Function(int questionId, String text) onEssayChanged;
  final Future<void> Function(ExamAttemptSessionState session) onTapFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // PageView -- swipe kiri/kanan pindah soal (item #3). onPageChanged
          // cuma dipanggil untuk swipe MANUAL user; perpindahan dari tombol
          // Sebelumnya/Selanjutnya atau grid navigator diurus lewat
          // _syncPageController di parent (jumpToPage), bukan lewat sini,
          // jadi tidak ada dobel-panggil goToQuestion untuk aksi yang sama.
          child: PageView.builder(
            controller: pageController,
            itemCount: session.totalQuestions,
            onPageChanged: notifier.goToQuestion,
            itemBuilder: (context, index) {
              final question = session.orderedQuestions[index];
              final answer = session.answers[question.id];
              return _QuestionPage(
                question: question,
                answer: answer,
                onEssayChanged: onEssayChanged,
                onSelectOption: (optionId) =>
                    notifier.selectOption(questionId: question.id, optionId: optionId),
                onToggleFlag: () => notifier.toggleFlag(question.id),
              );
            },
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

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.answer,
    required this.onEssayChanged,
    required this.onSelectOption,
    required this.onToggleFlag,
  });

  final ExamQuestion question;
  final LocalAnswer? answer;
  final void Function(int questionId, String text) onEssayChanged;
  final ValueChanged<int> onSelectOption;
  final VoidCallback onToggleFlag;

  @override
  Widget build(BuildContext context) {
    final isFlagged = answer?.isFlagged ?? false;

    return SingleChildScrollView(
      // Key per soal -- penting supaya SingleChildScrollView tidak
      // "mewarisi" posisi scroll dari soal sebelumnya begitu PageView
      // pindah halaman (tanpa ini, soal panjang bisa kebuka di tengah).
      key: PageStorageKey(question.id),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              // Tombol ragu-ragu (item #2) -- toggle murni lokal, tidak
              // memengaruhi status terjawab/kosong sama sekali.
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onToggleFlag,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFlagged ? AppColors.gold100 : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFlagged ? AppColors.gold500 : AppColors.neutral200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFlagged ? Icons.bookmark : Icons.bookmark_outline,
                        size: 15,
                        color: isFlagged ? AppColors.gold600 : AppColors.neutral500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ragu-ragu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFlagged ? AppColors.gold600 : AppColors.neutral500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                  onTap: () => onSelectOption(option.id),
                ),
              ),
        ],
      ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.answeredCount} dari ${session.totalQuestions} soal terjawab',
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: AppColors.brand500, label: 'Terjawab'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.gold500, label: 'Ragu-ragu'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.neutral300, label: 'Kosong'),
              ],
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
                  final isFlagged = answer?.isFlagged ?? false;
                  final isCurrent = index == session.currentIndex;

                  // Prioritas warna kalau current: brand500 solid selalu
                  // menang (biar posisi user tetap jelas) -- ragu-ragu cuma
                  // tampil sebagai warna dasar untuk soal yang BUKAN sedang
                  // dibuka.
                  final Color fillColor = isCurrent
                      ? AppColors.brand500
                      : isFlagged
                          ? AppColors.gold100
                          : isAnswered
                              ? AppColors.brand50
                              : AppColors.neutral100;
                  final Color borderColor = isCurrent
                      ? AppColors.brand500
                      : isFlagged
                          ? AppColors.gold500
                          : AppColors.neutral200;
                  final Color textColor = isCurrent ? Colors.white : AppColors.neutral900;

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: textColor,
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.neutral500)),
      ],
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
DART_EOF

echo "Fix stale summary cache diterapkan. Hot restart app (bukan hot reload) untuk apply."
