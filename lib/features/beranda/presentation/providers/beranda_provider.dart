// lib/features/beranda/presentation/providers/beranda_provider.dart
//
// PENTING: beranda_screen.dart cuma import file ini (bukan
// data/models/beranda_models.dart langsung), jadi model-model yang
// dipakai widget (ContinueExamData, RecommendedPackage, PromoBanner) di-
// export ulang di bawah supaya tetap terlihat dari satu import itu.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/beranda_repository.dart';
import '../../data/models/beranda_models.dart';

export '../../data/models/beranda_models.dart';

part 'beranda_provider.g.dart';

@riverpod
class BerandaNotifier extends _$BerandaNotifier {
  @override
  Future<BerandaData> build() async {
    final raw = await ref.watch(berandaRepositoryProvider).getBerandaData();

    final userName = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (user) => user.name,
          orElse: () => '',
        );

    return BerandaData(
      userName: userName,
      continueExam: raw.continueExam,
      hasActiveSubscription: raw.subscription?.isActive ?? false,
      subscriptionPackageName: raw.subscription?.plan?.name,
      recommendedPackages: raw.recommendedPackages,
      promoBanners: raw.promoBanners,
      streakDays: raw.performance.streak.count,
      averageScore: _averageScoreFrom(raw.performance),
      rank: raw.performance.ranking?.rank ?? 0,
      unreadNotificationCount: raw.unreadNotificationCount,
      performance: raw.performance,
      subscriptionPlans: raw.subscriptionPlans,
    );
  }

  /// Skor rata-rata dihitung dari [PerformanceSummary.sections] (rata-rata
  /// current_score tiap section, mis. TWK/TIU/TKP) -- data ini sudah
  /// di-fetch buat _StatsRow lama tapi sebelumnya tidak dipakai (hardcoded
  /// 0 dengan TODO). Section dengan topics locked (access.full=false)
  /// TETAP dihitung -- current_score section itu sendiri bukan bagian yang
  /// dikunci, hanya breakdown topik di dalamnya.
  double _averageScoreFrom(PerformanceSummary performance) {
    if (performance.sections.isEmpty) return 0;
    final total = performance.sections.fold<double>(
      0,
      (sum, section) => sum + section.currentScore,
    );
    return total / performance.sections.length;
  }

  /// Dipanggil dari pull-to-refresh di layar Beranda.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
