// lib/features/leaderboard/presentation/screens/leaderboard_screen.dart
//
// Tab "Peringkat" -- Leaderboard Latihan Soal mingguan. Dropdown pilih
// exam (yang punya leaderboard aktif periode berjalan) -> kartu posisi
// user sendiri -> Top 50. TIDAK ada logika exam_batch_id sama sekali,
// lihat catatan di data/models/leaderboard_model.dart kenapa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(leaderboardRankedExamsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Peringkat'),
      ),
      body: rankedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat leaderboard',
          onRetry: () => ref.invalidate(leaderboardRankedExamsProvider),
        ),
        data: (ranked) {
          if (ranked.data.isEmpty) return const _EmptyRankedState();
          return _LeaderboardBody(rankedExams: ranked.data);
        },
      ),
    );
  }
}

class _LeaderboardBody extends ConsumerWidget {
  const _LeaderboardBody({required this.rankedExams});
  final List<LeaderboardRankedExam> rankedExams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Default ke exam pertama kalau user belum pernah pilih secara
    // eksplisit -- dihitung inline (bukan disuntik ke provider saat
    // build) supaya build() tetap murni, tidak trigger rebuild tambahan.
    final selectedId =
        ref.watch(selectedLeaderboardExamIdProvider) ?? rankedExams.first.id;
    final currentUserId = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (user) => user.id,
          orElse: () => null,
        );

    final entriesAsync = ref.watch(leaderboardEntriesProvider(selectedId));
    final myPositionAsync = ref.watch(leaderboardMyPositionProvider(selectedId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardEntriesProvider(selectedId));
        ref.invalidate(leaderboardMyPositionProvider(selectedId));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _ExamDropdown(
            rankedExams: rankedExams,
            selectedId: selectedId,
            onChanged: (id) =>
                ref.read(selectedLeaderboardExamIdProvider.notifier).select(id),
          ),
          const SizedBox(height: 16),
          myPositionAsync.when(
            loading: () => const _MyPositionSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (myPosition) => myPosition == null
                ? const _NoRankingYetCard()
                : _MyPositionCard(myPosition: myPosition),
          ),
          const SizedBox(height: 20),
          const Text(
            'Top 50 Minggu Ini',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              message: error is ApiException ? error.message : 'Gagal memuat ranking',
              onRetry: () => ref.invalidate(leaderboardEntriesProvider(selectedId)),
            ),
            data: (index) {
              if (index.data.isEmpty) return const _EmptyEntriesState();
              return Column(
                children: [
                  for (final entry in index.data)
                    _EntryRow(entry: entry, isMe: entry.userId == currentUserId),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExamDropdown extends StatelessWidget {
  const _ExamDropdown({
    required this.rankedExams,
    required this.selectedId,
    required this.onChanged,
  });

  final List<LeaderboardRankedExam> rankedExams;
  final int selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.neutral500),
          items: [
            for (final exam in rankedExams)
              DropdownMenuItem(
                value: exam.id,
                child: Text(
                  '${exam.title} · ${exam.participantsCount} peserta',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

class _MyPositionCard extends StatelessWidget {
  const _MyPositionCard({required this.myPosition});
  final LeaderboardMyPosition myPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Posisi Kamu',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${myPosition.ranking}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'dari ${myPosition.totalPeserta} peserta',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Skor terbaik: ${myPosition.skorTerbaik}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (myPosition.rewardType != null) ...[
            const SizedBox(height: 10),
            _RewardBadge(rewardType: myPosition.rewardType!, onDark: true),
          ],
        ],
      ),
    );
  }
}

class _NoRankingYetCard extends StatelessWidget {
  const _NoRankingYetCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.neutral400, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kamu belum punya ranking di exam ini minggu ini. Kerjakan latihan soalnya buat mulai bersaing!',
              style: TextStyle(color: AppColors.neutral600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPositionSkeleton extends StatelessWidget {
  const _MyPositionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.brand50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? AppColors.brand200 : AppColors.neutral200),
      ),
      child: Row(
        children: [
          _RankBadge(ranking: entry.ranking),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.user?.name ?? 'Peserta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (entry.rewardType != null) ...[
                  const SizedBox(height: 4),
                  _RewardBadge(rewardType: entry.rewardType!, onDark: false),
                ],
              ],
            ),
          ),
          Text(
            '${entry.skorTerbaik}',
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.ranking});
  final int ranking;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (ranking) {
      1 => (AppColors.gold600, AppColors.gold100),
      2 => (AppColors.neutral600, AppColors.neutral100),
      3 => (AppColors.brand600, AppColors.brand100),
      _ => (AppColors.neutral500, AppColors.neutral50),
    };
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '$ranking',
        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.rewardType, required this.onDark});
  final LeaderboardRewardType rewardType;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final label = switch (rewardType) {
      LeaderboardRewardType.voucherGold => 'Voucher Emas',
      LeaderboardRewardType.voucherSilver => 'Voucher Perak',
      LeaderboardRewardType.voucherBronze => 'Voucher Perunggu',
      LeaderboardRewardType.badgeOnly => 'Lencana Top Peserta',
    };
    final bg = onDark ? Colors.white.withOpacity(0.18) : AppColors.gold100;
    final fg = onDark ? Colors.white : AppColors.gold600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyRankedState extends StatelessWidget {
  const _EmptyRankedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.leaderboard_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada leaderboard aktif minggu ini',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kerjakan latihan soal supaya leaderboard mingguan mulai terbentuk.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEntriesState extends StatelessWidget {
  const _EmptyEntriesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Belum ada peserta di ranking exam ini.',
          style: TextStyle(color: AppColors.neutral500, fontSize: 13),
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

