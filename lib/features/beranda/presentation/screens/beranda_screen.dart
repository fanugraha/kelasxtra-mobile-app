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

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.exam});
  final ContinueExamData? exam;

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                // TODO: hasExam ? lanjut ke exam_engine dgn attemptId : ke katalog latihan.
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

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
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
