// lib/features/exam_engine/presentation/screens/topic_mastery_history_screen.dart
//
// GET /me/topic-mastery-history -- grafik tren mastery mingguan 1 topik.
// Chart di-hand-roll pakai Container biasa (bukan pakai package chart
// baru seperti fl_chart) -- data time-series-nya sederhana (<=52 titik,
// cuma butuh bar + label), konsisten dengan gaya project ini yang lebih
// suka nulis manual daripada nambah dependency baru untuk hal sederhana
// (lihat catatan di core/utils/formatters.dart soal DateFormat).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/exam_provider.dart';

class TopicMasteryHistoryScreen extends ConsumerWidget {
  const TopicMasteryHistoryScreen({super.key, required this.topicId, this.topicName});

  final int topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(topicMasteryHistoryProvider(topicId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(topicName != null ? 'Riwayat -- $topicName' : 'Riwayat Mastery'),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat riwayat mastery',
          onRetry: () => ref.invalidate(topicMasteryHistoryProvider(topicId)),
        ),
        data: (history) {
          if (!history.access.full) {
            return _LockedState(cta: history.access.upgradeCta);
          }
          if (history.periods.isEmpty) {
            return const _NoHistoryState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(topicMasteryHistoryProvider(topicId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _LatestSnapshotCard(latest: history.periods.last),
                const SizedBox(height: 20),
                const Text(
                  'Tren Mingguan',
                  style: TextStyle(color: AppColors.neutral900, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _MasteryChart(periods: history.periods),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LatestSnapshotCard extends StatelessWidget {
  const _LatestSnapshotCard({required this.latest});
  final TopicMasteryPeriod latest;

  @override
  Widget build(BuildContext context) {
    final trendIcon = switch (latest.trend) {
      'up' => Icons.trending_up,
      'down' => Icons.trending_down,
      _ => Icons.trending_flat,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mastery Minggu Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${latest.percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  '${latest.correctCount}/${latest.totalCount} soal benar -- ${_formatPeriode(latest.period)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(trendIcon, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

/// Chart bar sederhana -- 1 kolom per periode, tinggi bar proporsional ke
/// percentage (0-100). Discroll horizontal kalau periode-nya banyak
/// (server bisa balikin sampai 52 minggu).
class _MasteryChart extends StatelessWidget {
  const _MasteryChart({required this.periods});
  final List<TopicMasteryPeriod> periods;

  static const _chartHeight = 140.0;
  static const _barWidth = 28.0;
  static const _columnWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // langsung scroll ke periode terbaru (kanan)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final period in periods) _ChartColumn(period: period),
          ],
        ),
      ),
    );
  }
}

class _ChartColumn extends StatelessWidget {
  const _ChartColumn({required this.period});
  final TopicMasteryPeriod period;

  @override
  Widget build(BuildContext context) {
    final pct = period.percentage.clamp(0, 100).toDouble();
    final color = pct < 60
        ? AppColors.danger600
        : pct < 80
            ? AppColors.gold600
            : AppColors.success600;
    final barHeight = (_MasteryChart._chartHeight - 34) * (pct / 100);

    return SizedBox(
      width: _MasteryChart._columnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${pct.toStringAsFixed(0)}',
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            width: _MasteryChart._barWidth,
            height: barHeight.clamp(2.0, _MasteryChart._chartHeight).toDouble(),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPeriodeSingkat(period.period),
            style: const TextStyle(color: AppColors.neutral500, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}

/// "2026-W29" -> "Minggu ke-29, 2026"
String _formatPeriode(String period) {
  final match = RegExp(r'^(\d{4})-W(\d{1,2})$').firstMatch(period);
  if (match == null) return period;
  return 'Minggu ke-${int.parse(match.group(2)!)}, ${match.group(1)}';
}

/// "2026-W29" -> "W29" (label sumbu-x, harus ringkas)
String _formatPeriodeSingkat(String period) {
  final match = RegExp(r'^\d{4}-W(\d{1,2})$').firstMatch(period);
  if (match == null) return period;
  return 'W${match.group(1)}';
}

class _LockedState extends StatelessWidget {
  const _LockedState({required this.cta});
  final TopicMasteryUpgradeCta? cta;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.gold600, size: 44),
            const SizedBox(height: 14),
            Text(
              cta?.message ?? 'Riwayat mastery lengkap terkunci -- upgrade paket untuk membukanya.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral700, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              // action_link dari backend berformat path web, tidak match
              // route Flutter app ini -- arahkan ke Paket Saya seperti pola
              // yang sama dipakai di AnalisisPerformaScreen.
              onPressed: () => context.push('/paket-saya'),
              child: const Text('Lihat Paket Saya'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHistoryState extends StatelessWidget {
  const _NoHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.show_chart, color: AppColors.neutral300, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Belum ada riwayat mingguan',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Riwayat mastery terbentuk tiap minggu dari latihan soal topik ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
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
