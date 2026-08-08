// lib/features/beranda/presentation/screens/analisis_performa_screen.dart
//
// Konsumsi PerformanceSummary yang sudah di-fetch Beranda (berandaNotifierProvider)
// -- SENGAJA tidak panggil GET /me/performance-summary sendiri, supaya buka
// layar ini tidak nambah 1 request lagi selain yang sudah dilakukan Beranda.
// Konsekuensinya: data di sini seusia data Beranda terakhir; pull-to-refresh
// di sini memicu refresh Beranda juga (lewat BerandaNotifier.refresh()).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../exam_engine/presentation/screens/topic_performance_screen.dart';
import '../providers/beranda_provider.dart';

class AnalisisPerformaScreen extends ConsumerWidget {
  const AnalisisPerformaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Analisis Performa'),
      ),
      body: berandaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat data performa',
          onRetry: () => ref.read(berandaNotifierProvider.notifier).refresh(),
        ),
        data: (beranda) {
          final performance = beranda.performance;
          return RefreshIndicator(
            onRefresh: () => ref.read(berandaNotifierProvider.notifier).refresh(),
            child: switch (performance.state) {
              PerformanceState.noAttempts => _NoAttemptsState(cta: performance.cta),
              PerformanceState.insufficientAttempts =>
                _PerformanceBody(performance: performance, showInsufficientBanner: true),
              PerformanceState.ready =>
                _PerformanceBody(performance: performance, showInsufficientBanner: false),
            },
          );
        },
      ),
    );
  }
}

class _NoAttemptsState extends StatelessWidget {
  const _NoAttemptsState({required this.cta});
  final PerformanceCta? cta;

  @override
  Widget build(BuildContext context) {
    // ListView (bukan Column+Center) supaya RefreshIndicator tetap bisa
    // di-pull walau kontennya pendek/tidak scrollable.
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.query_stats_outlined, size: 56, color: AppColors.neutral300),
        const SizedBox(height: 16),
        Text(
          cta?.message ?? 'Belum ada data try-out untuk dianalisis.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.neutral700, fontSize: 14, height: 1.5),
        ),
        if (cta != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              // action_link dari backend berformat path web (mis.
              // "/app/packages?..."), tidak match route Flutter app ini --
              // arahkan ke Paket Saya (Fase 0, sudah ada) sebagai tujuan
              // paling relevan yang benar-benar ada saat ini.
              onPressed: () => context.push('/paket-saya'),
              child: const Text('Lihat Paket Saya'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PerformanceBody extends StatelessWidget {
  const _PerformanceBody({required this.performance, required this.showInsufficientBanner});

  final PerformanceSummary performance;
  final bool showInsufficientBanner;

  @override
  Widget build(BuildContext context) {
    final access = performance.access;
    final showUpgradeBanner = access != null && !access.full && access.upgradeCta != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _StreakCard(streak: performance.streak),
        // Link ke "Semua Topik" (GET /me/topic-performance) -- ranking
        // topik LINTAS SEMUA EXAM dalam program ini, beda dari
        // sections di bawah yang dikelompokkan per section/exam.
        // programId wajib untuk query itu, jadi disembunyikan kalau
        // backend tidak mengirim `program` (mis. belum ada attempt sama
        // sekali -- state itu ditangani _NoAttemptsState, bukan di sini,
        // tapi dijaga juga untuk kondisi lain yang tidak terduga).
        if (performance.program != null) ...[
          const SizedBox(height: 14),
          _AllTopicsLink(programId: performance.program!.id, programName: performance.program!.name),
        ],
        if (showInsufficientBanner) ...[
          const SizedBox(height: 14),
          const _InfoBanner(
            icon: Icons.info_outline,
            text:
                'Data kamu masih terbatas -- kerjakan lebih banyak try-out supaya analisis per topik lebih akurat.',
          ),
        ],
        if (showUpgradeBanner) ...[
          const SizedBox(height: 14),
          _UpgradeBanner(cta: access.upgradeCta!),
        ],
        if (performance.topRecommendations.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Rekomendasi Belajar'),
          const SizedBox(height: 10),
          for (final rec in performance.topRecommendations)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RecommendationCard(recommendation: rec),
            ),
        ],
        if (performance.sections.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Peta Kekuatan per Section'),
          const SizedBox(height: 10),
          for (final section in performance.sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SectionCard(section: section),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.neutral900,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});
  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streak.count} hari beruntun',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak.activeToday
                      ? 'Sudah belajar hari ini, pertahankan!'
                      : 'Belum belajar hari ini -- yuk lanjutkan streak-mu.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTopicsLink extends StatelessWidget {
  const _AllTopicsLink({required this.programId, required this.programName});
  final int programId;
  final String programName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/analisis-performa/topik',
        extra: TopicPerformanceArgs(programId: programId, programName: programName),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            const Icon(Icons.list_alt_outlined, size: 18, color: AppColors.brand600),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Lihat Semua Topik',
                style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.neutral500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.neutral600, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.cta});
  final PerformanceCta cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold500),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.gold600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              cta.message,
              style: const TextStyle(color: AppColors.gold600, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          // Lihat catatan action_link di _NoAttemptsState -- sama-sama
          // diarahkan ke Paket Saya, bukan mengikuti action_link mentah.
          TextButton(
            onPressed: () => context.push('/paket-saya'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.gold600,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.recommendation});
  final TopRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // practice_link dari backend belum match route app ini (lihat catatan
      // di _NoAttemptsState), jadi tidak dipakai. Push langsung pakai
      // recommendation.topicId ke roadmap topik terkait -- diverifikasi
      // topic_id di sini pakai id Topic model yang sama dengan route model
      // binding /latihan-soal/topics/{topic}/roadmap di backend
      // (TopicPracticeController::roadmap), jadi aman dipakai langsung.
      onTap: () => context.push(
        '/latihan-soal/topik/${recommendation.topicId}',
        extra: recommendation.topicName,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brand500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                recommendation.sectionCode,
                style: const TextStyle(
                  color: AppColors.brand600,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.topicName,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.message,
                    style: const TextStyle(color: AppColors.neutral600, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final PerformanceSection section;

  @override
  Widget build(BuildContext context) {
    // gap_to_pass nullable di spec -- kalau null (mis. section ini tidak
    // ada ambang kelulusan terpisah), sembunyikan baris gap sama sekali
    // daripada menampilkan angka yang menyesatkan (mis. "0" seolah sudah
    // pas di batas).
    final gap = section.gapToPass;

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
              Expanded(
                child: Text(
                  section.name,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: section.isPassed ? AppColors.success50 : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  section.isPassed ? 'Lulus' : 'Belum Lulus',
                  style: TextStyle(
                    color: section.isPassed ? AppColors.success700 : AppColors.neutral600,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            section.minPassingScore != null
                ? 'Skor: ${section.currentScore.toStringAsFixed(0)} / ${section.minPassingScore} (ambang lulus)'
                : 'Skor: ${section.currentScore.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
          ),
          if (gap != null && gap > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Kurang $gap poin lagi untuk lulus section ini.',
              style: const TextStyle(color: AppColors.gold600, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          if (section.topicsLocked)
            const _LockedTopicsPlaceholder()
          else
            for (final topic in section.topics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TopicRow(topic: topic),
              ),
        ],
      ),
    );
  }
}

class _LockedTopicsPlaceholder extends StatelessWidget {
  const _LockedTopicsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.neutral400),
          SizedBox(width: 6),
          Text(
            'Detail per topik terkunci -- upgrade paket untuk membukanya',
            style: TextStyle(color: AppColors.neutral500, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});
  final PerformanceTopic topic;

  @override
  Widget build(BuildContext context) {
    final color = switch (topic.level) {
      TopicLevel.weak => AppColors.danger600,
      TopicLevel.medium => AppColors.gold600,
      TopicLevel.strong => AppColors.success600,
      TopicLevel.insufficientData => AppColors.neutral400,
    };

    final trend = topic.trend;
    final trendIcon = switch (trend) {
      TopicTrend.up => Icons.trending_up,
      TopicTrend.down => Icons.trending_down,
      TopicTrend.stable => Icons.trending_flat,
      null => null,
    };

    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            topic.name,
            style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5),
          ),
        ),
        if (trendIcon != null) ...[
          Icon(trendIcon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(
            topic.percentage != null ? '${topic.percentage}% -- ${topic.label}' : topic.label,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
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
