mkdir -p lib/core/utils lib/features/katalog/data/repositories lib/features/katalog/presentation/providers
rm -f lib/core/router/app_router.dart.orig

cat > lib/core/utils/formatters.dart << 'EOF_FORMATTERS'
// lib/core/utils/formatters.dart
//
// Formatter angka/tanggal kecil yang dipakai lintas modul (transaksi,
// subscription, katalog, beranda) -- sebelumnya terduplikasi persis sama
// di beberapa tempat (transaksi_format.dart, subscription_format.dart,
// _formatRupiah privat di beranda_screen.dart). Dikonsolidasi ke sini
// supaya modul baru (katalog, dst) tidak nambah copy lagi.
//
// Sengaja hand-rolled, bukan intl's DateFormat/NumberFormat.currency --
// itu butuh initializeDateFormatting('id_ID') dulu di main.dart yang belum
// ada di project ini, dan formatnya cukup sederhana untuk ditulis manual.

const _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// 150000.0 -> "Rp150.000"
String formatRupiah(double amount) {
  final rounded = amount.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
  }

  return 'Rp$buffer';
}

/// "2026-08-02T10:15:00.000000Z" -> "2 Agu 2026, 10:15"
String formatTanggal(String? isoString) {
  if (isoString == null) return '-';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '-';
  final local = date.toLocal();
  final jam = local.hour.toString().padLeft(2, '0');
  final menit = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}, $jam:$menit';
}

/// "2026-08-02" atau "2026-08-02T00:00:00.000000Z" -> "2 Agu 2026"
String formatTanggalSingkat(String? dateString) {
  if (dateString == null) return '-';
  final date = DateTime.tryParse(dateString);
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}';
}

/// 30 -> "30 hari", 365 -> "1 tahun", 90 -> "3 bulan" (pembulatan kasar,
/// cukup buat label kartu plan/paket).
String formatDurasi(int days) {
  if (days % 365 == 0 && days >= 365) {
    final years = days ~/ 365;
    return years == 1 ? '1 tahun' : '$years tahun';
  }
  if (days % 30 == 0 && days >= 30) {
    final months = days ~/ 30;
    return months == 1 ? '1 bulan' : '$months bulan';
  }
  return '$days hari';
}
EOF_FORMATTERS

cat > lib/features/transaksi/presentation/screens/transaksi_format.dart << 'EOF_TXFORMAT'
// lib/features/transaksi/presentation/screens/transaksi_format.dart
//
// Re-export dari core/utils/formatters.dart -- dipertahankan sebagai file
// terpisah supaya import di transaksi_detail_screen.dart/
// riwayat_transaksi_screen.dart tidak perlu diubah, tapi implementasinya
// sekarang satu sumber (konsolidasi dari 3 copy identik sebelumnya --
// lihat catatan lengkap di core/utils/formatters.dart).
export '../../../../core/utils/formatters.dart';
EOF_TXFORMAT

cat > lib/features/subscription/presentation/screens/subscription_format.dart << 'EOF_SUBFORMAT'
// lib/features/subscription/presentation/screens/subscription_format.dart
//
// Re-export dari core/utils/formatters.dart -- lihat catatan di
// transaksi_format.dart.
export '../../../../core/utils/formatters.dart';
EOF_SUBFORMAT

cat > lib/features/beranda/presentation/screens/beranda_screen.dart << 'EOF_BERANDA'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
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

/// Grid akses cepat, 3 item (bukan 4 -- lihat catatan di bawah), tiap item
/// push langsung ke rute tujuannya (bukan cuma ganti tab bottom-nav lalu
/// user tap lagi).
///
/// Dulu ada tile ke-4 "Latihan Fokus" ("Perkuat kelemahanmu") terpisah dari
/// "Latihan Soal per Topik" -- dihapus karena keduanya SATU fitur yang sama
/// (endpoint /latihan-soal/categories -> topics -> roadmap, ditag "Latihan
/// Fokus" di kelasxtra-openapi.yaml). Tile "Latihan Fokus" cuma mendarat di
/// kategori generik yang sama, jadi subtitle "Perkuat kelemahanmu" menjanjikan
/// sesuatu yang tidak benar-benar ada (tidak ada personalisasi kelemahan di
/// screen itu) -- membingungkan, bukan cuma duplikat kosmetik.
///
/// "Analisis Performa" push ke AnalisisPerformaScreen (konsumsi
/// PerformanceSummary penuh dari BerandaData.performance -- reuse cache
/// Beranda, tidak ada request tambahan).
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  static const _items = [
    (
      icon: Icons.topic_outlined,
      title: 'Latihan Soal per Topik',
      subtitle: 'Susun roadmap topik',
      route: '/latihan-soal',
    ),
    (
      icon: Icons.timer_outlined,
      title: 'Tryout',
      subtitle: 'Simulasi CAT penuh',
      route: '/tryout',
    ),
    (
      icon: Icons.insights_outlined,
      title: 'Analisis Performa',
      subtitle: 'Lihat progres belajarmu',
      route: '/analisis-performa',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i != 0) const SizedBox(width: 12),
            Expanded(child: _buildTile(context, _items[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, ({IconData icon, String title, String subtitle, String route}) item) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(item.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: AppColors.brand500, size: 22),
            const SizedBox(height: 16),
            Text(
              item.title,
              maxLines: 2,
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
  }
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
                        formatRupiah(package.discountPrice ?? package.price),
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
                              formatRupiah(package.price),
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

cat > lib/features/transaksi/presentation/screens/checkout_webview_screen.dart << 'EOF_CHECKOUT'
// lib/features/transaksi/presentation/screens/checkout_webview_screen.dart
//
// WebView Midtrans Snap. Snap URL ini TIDAK punya finish_redirect_url yang
// dikonfigurasi di backend (dicek langsung ke MidtransService -- tidak ada
// Config::$finishRedirectUrl atau semacamnya), jadi kita tidak bisa
// mengandalkan navigasi WebView balik ke URL tertentu untuk tahu
// pembayaran selesai. Pendekatan yang dipakai: polling GET
// /transactions/{id} tiap beberapa detik selagi layar ini terbuka -- begitu
// status berubah dari pending, auto-tutup & laporkan hasilnya ke caller.
//
// PLATFORM: webview_flutter TIDAK punya implementasi untuk Flutter Web
// (WebViewPlatform.instance null -> crash). Target rilis app ini
// Android/iOS jadi WebView asli dipakai di sana, tapi supaya tetap bisa
// dites cepat lewat `flutter run -d chrome`, di web kita buka Snap di tab
// baru pakai url_launcher dan tetap polling status di background --
// hasilnya sama-sama terdeteksi otomatis, cuma UI pembayarannya di luar
// app untuk kasus web ini.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../data/repositories/transaksi_repository.dart';
import '../providers/transaksi_provider.dart';

/// Argumen dikirim lewat go_router `extra` ke rute /checkout (bukan path
/// param biasa karena snapToken terlalu panjang/tidak URL-safe kalau
/// dipaksa jadi query param).
class CheckoutArgs {
  const CheckoutArgs({required this.transactionId, required this.snapToken});
  final int transactionId;
  final String snapToken;
}

/// Hasil yang dikembalikan ke layar sebelumnya lewat context.pop(result)
/// begitu CheckoutWebViewScreen ditutup (baik otomatis via polling maupun
/// manual lewat tombol back) -- supaya caller tahu perlu refresh data atau
/// tidak, tanpa perlu tebak-tebak dari provider invalidation semata.
class CheckoutResult {
  const CheckoutResult({required this.transactionId, required this.status});
  final int transactionId;
  final TransactionStatus status;
}

class CheckoutWebViewScreen extends ConsumerStatefulWidget {
  const CheckoutWebViewScreen({
    super.key,
    required this.transactionId,
    required this.snapToken,
  });

  final int transactionId;
  final String snapToken;

  @override
  ConsumerState<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends ConsumerState<CheckoutWebViewScreen> {
  WebViewController? _controller;
  late final Uri _snapUrl;
  Timer? _pollTimer;
  bool _isLoadingPage = true;
  bool _isCheckingStatus = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();

    _snapUrl = Uri.parse('${AppConfig.midtransSnapBaseUrl}/${widget.snapToken}');

    if (kIsWeb) {
      _isLoadingPage = false;
      _openInNewTab();
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) => setState(() => _isLoadingPage = true),
            onPageFinished: (_) => setState(() => _isLoadingPage = false),
          ),
        )
        ..loadRequest(_snapUrl);
    }

    // Poll tiap 4 detik -- cukup responsif tanpa membanjiri backend selagi
    // user isi form pembayaran.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
  }

  Future<void> _openInNewTab() async {
    await launchUrl(_snapUrl, webOnlyWindowName: '_blank');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus({bool showLoadingIndicator = false}) async {
    if (_closed) return;
    if (showLoadingIndicator) setState(() => _isCheckingStatus = true);

    try {
      final transaction = await ref.read(transaksiRepositoryProvider).getTransactionDetail(widget.transactionId);

      if (!mounted) return;
      if (showLoadingIndicator) setState(() => _isCheckingStatus = false);

      if (transaction.status != TransactionStatus.pending) {
        _finish(transaction.status);
      }
    } catch (_) {
      // Gagal-lembut -- koneksi sempat putus pas polling bukan alasan
      // nutup paksa, coba lagi di tick berikutnya / tombol manual.
      if (mounted && showLoadingIndicator) setState(() => _isCheckingStatus = false);
    }
  }

  void _finish(TransactionStatus status) {
    if (_closed) return;
    _closed = true;
    _pollTimer?.cancel();

    // Refresh riwayat & detail supaya begitu user balik ke layar
    // sebelumnya, datanya sudah status terbaru -- bukan nunggu manual
    // pull-to-refresh. Checkout endpoint ini dipakai bersama untuk beli
    // paket ATAU subscription (lihat catatan CheckoutArgs) -- invalidate
    // dua-duanya sekaligus daripada caller harus tahu mana yang dibeli.
    ref.invalidate(transaksiNotifierProvider);
    ref.invalidate(transaksiDetailProvider(widget.transactionId));
    ref.invalidate(mySubscriptionNotifierProvider);
    ref.invalidate(enrollmentNotifierProvider);

    Navigator.of(context).pop(CheckoutResult(transactionId: widget.transactionId, status: status));
  }

  Future<bool> _handleManualClose() async {
    // Cek status sekali lagi pas user coba keluar manual -- jaga-jaga
    // pembayaran sebenarnya sudah selesai tapi tick polling berikutnya
    // belum sempat jalan.
    await _checkStatus();
    return !_closed;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _handleManualClose();
        if (canPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.neutral50,
        appBar: AppBar(
          backgroundColor: AppColors.neutral50,
          title: const Text('Pembayaran'),
          actions: [
            IconButton(
              tooltip: 'Cek status pembayaran',
              icon: _isCheckingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isCheckingStatus ? null : () => _checkStatus(showLoadingIndicator: true),
            ),
          ],
        ),
        body: kIsWeb ? _WebFallbackBody(onReopen: _openInNewTab) : _buildWebView(),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoadingPage) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// Body khusus web -- WebView asli tidak bisa dipakai, jadi pembayaran
/// dibuka di tab baru dan layar ini cuma menunggu + polling status.
class _WebFallbackBody extends StatelessWidget {
  const _WebFallbackBody({required this.onReopen});
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.open_in_new, color: AppColors.brand500, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Pembayaran dibuka di tab baru',
              style: TextStyle(color: AppColors.neutral900, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selesaikan pembayaran di tab yang baru terbuka. Halaman ini otomatis lanjut begitu pembayaran terdeteksi selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Buka Lagi Tab Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }
}

EOF_CHECKOUT

cat > lib/features/katalog/data/katalog_api_service.dart << 'EOF_KATAPI'
// lib/features/katalog/data/katalog_api_service.dart
//
// Panggilan HTTP mentah untuk katalog paket (beli baru) -- GET /packages
// TIDAK punya filter `type` di server (cuma `program_id`, lihat spec),
// jadi filter per PackageType (reguler=Tryout, latihan_soal=Latihan Soal)
// dilakukan client-side di provider/screen, bukan di query param.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/package_model.dart';

part 'katalog_api_service.g.dart';

class KatalogApiService {
  KatalogApiService(this._dio);

  final Dio _dio;

  /// GET /packages -- daftar semua paket yang bisa dibeli (bukan yang
  /// sudah dimiliki user -- itu /my-packages, lihat EnrollmentRepository).
  Future<List<PackageModel>> getPackages({int? programId}) async {
    final response = await _dio.get(
      ApiEndpoints.packages,
      queryParameters: programId != null ? {'program_id': programId} : null,
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => PackageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    final response = await _dio.get(ApiEndpoints.packageDetail(packageId));
    return PackageModel.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
KatalogApiService katalogApiService(KatalogApiServiceRef ref) {
  return KatalogApiService(ref.watch(dioProvider));
}
EOF_KATAPI

cat > lib/features/katalog/data/repositories/katalog_repository.dart << 'EOF_KATREPO'
// lib/features/katalog/data/repositories/katalog_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../katalog_api_service.dart';
import '../models/package_model.dart';

part 'katalog_repository.g.dart';

class KatalogRepository {
  KatalogRepository(this._api);

  final KatalogApiService _api;

  Future<List<PackageModel>> getPackages({int? programId}) async {
    try {
      return await _api.getPackages(programId: programId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    try {
      return await _api.getPackageDetail(packageId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
KatalogRepository katalogRepository(KatalogRepositoryRef ref) {
  return KatalogRepository(ref.watch(katalogApiServiceProvider));
}
EOF_KATREPO

cat > lib/features/katalog/presentation/providers/katalog_provider.dart << 'EOF_KATPROV'
// lib/features/katalog/presentation/providers/katalog_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/package_model.dart';
import '../../data/repositories/katalog_repository.dart';

export '../../data/models/package_model.dart';

part 'katalog_provider.g.dart';

@riverpod
class KatalogNotifier extends _$KatalogNotifier {
  @override
  Future<List<PackageModel>> build() {
    return ref.watch(katalogRepositoryProvider).getPackages();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
EOF_KATPROV

cat > lib/features/katalog/presentation/screens/katalog_screen.dart << 'EOF_KATSCREEN'
// lib/features/katalog/presentation/screens/katalog_screen.dart
//
// Katalog paket beli-baru -- GET /packages (semua paket publik), difilter
// client-side ke PackageType.reguler (Tryout) & PackageType.latihanSoal
// (Latihan Soal) saja. privat/group SENGAJA disembunyikan -- itu paket
// kelas 1-on-1/grup dengan tutor, belum ada modul untuk itu (kelas_materi
// & tutor masih README-only, lihat dokumen status project).
//
// Status kepemilikan (badge "Dimiliki") dicek silang ke enrollmentNotifierProvider
// (cache /my-packages) -- tidak ada network call tambahan untuk itu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../transaksi/data/repositories/transaksi_repository.dart';
import '../../../transaksi/presentation/screens/checkout_webview_screen.dart';
import '../providers/katalog_provider.dart';

class KatalogScreen extends ConsumerStatefulWidget {
  const KatalogScreen({super.key, this.initialFilter});

  /// Prefilter saat masuk dari tempat yang sudah tahu konteksnya, mis. dari
  /// tombol kosong di TryoutScreen (filter = reguler). null = tampilkan
  /// semua jenis yang relevan.
  final PackageType? initialFilter;

  @override
  ConsumerState<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends ConsumerState<KatalogScreen> {
  PackageType? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(katalogNotifierProvider);
    final enrollmentsAsync = ref.watch(enrollmentNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Katalog Paket'),
      ),
      body: packagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat katalog paket',
          onRetry: () => ref.read(katalogNotifierProvider.notifier).refresh(),
        ),
        data: (packages) {
          final relevant = packages
              .where((p) => p.type == PackageType.reguler || p.type == PackageType.latihanSoal)
              .toList();
          final filtered =
              _filter == null ? relevant : relevant.where((p) => p.type == _filter).toList();

          final ownedActiveIds = enrollmentsAsync.valueOrNull
                  ?.where((e) => e.isActive)
                  .map((e) => e.package.id)
                  .toSet() ??
              const <int>{};

          return RefreshIndicator(
            onRefresh: () => ref.read(katalogNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _FilterChips(
                  selected: _filter,
                  onChanged: (type) => setState(() => _filter = type),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const _EmptyFilterState()
                else
                  for (final package in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PackageCard(
                        package: package,
                        isOwned: ownedActiveIds.contains(package.id),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});
  final PackageType? selected;
  final ValueChanged<PackageType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(label: 'Semua', isSelected: selected == null, onTap: () => onChanged(null)),
          const SizedBox(width: 8),
          _Chip(
            label: 'Tryout',
            isSelected: selected == PackageType.reguler,
            onTap: () => onChanged(PackageType.reguler),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Latihan Soal',
            isSelected: selected == PackageType.latihanSoal,
            onTap: () => onChanged(PackageType.latihanSoal),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.brand500 : AppColors.neutral200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.neutral700,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends ConsumerStatefulWidget {
  const _PackageCard({required this.package, required this.isOwned});
  final PackageModel package;
  final bool isOwned;

  @override
  ConsumerState<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends ConsumerState<_PackageCard> {
  bool _isBuying = false;

  Future<void> _handleBeli() async {
    setState(() => _isBuying = true);
    try {
      final transaction =
          await ref.read(transaksiRepositoryProvider).checkoutPackage(widget.package.id);
      final token = transaction.snapToken;
      if (token == null) throw Exception('Token pembayaran tidak tersedia. Coba lagi.');

      if (!mounted) return;
      await context.push<CheckoutResult>(
        '/checkout',
        extra: CheckoutArgs(transactionId: transaction.id, snapToken: token),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  void _openDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PackageDetailSheet(
        package: widget.package,
        isOwned: widget.isOwned,
        isBuying: _isBuying,
        onBeli: () {
          Navigator.of(sheetContext).pop();
          _handleBeli();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final hasDiscount = package.hasDiscount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: package.bannerImageUrl != null
                  ? Image.network(
                      package.bannerImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PackagePlaceholderIcon(type: package.type),
                    )
                  : _PackagePlaceholderIcon(type: package.type),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatRupiah(package.effectivePrice),
                          style: const TextStyle(
                            color: AppColors.brand600,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            formatRupiah(package.price),
                            style: const TextStyle(
                              color: AppColors.neutral400,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    widget.isOwned
                        ? const _OwnedBadge()
                        : SizedBox(
                            height: 30,
                            child: FilledButton(
                              onPressed: _isBuying ? null : _handleBeli,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              child: _isBuying
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Beli'),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagePlaceholderIcon extends StatelessWidget {
  const _PackagePlaceholderIcon({required this.type});
  final PackageType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutral100,
      alignment: Alignment.center,
      child: Icon(
        type == PackageType.reguler ? Icons.timer_outlined : Icons.topic_outlined,
        color: AppColors.neutral400,
      ),
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: AppColors.success700),
          SizedBox(width: 4),
          Text(
            'Dimiliki',
            style: TextStyle(color: AppColors.success700, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PackageDetailSheet extends StatelessWidget {
  const _PackageDetailSheet({
    required this.package,
    required this.isOwned,
    required this.isBuying,
    required this.onBeli,
  });

  final PackageModel package;
  final bool isOwned;
  final bool isBuying;
  final VoidCallback onBeli;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (package.bannerImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    package.bannerImageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                package.name,
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    formatRupiah(package.effectivePrice),
                    style: const TextStyle(
                      color: AppColors.brand600,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (package.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatRupiah(package.price),
                      style: const TextStyle(
                        color: AppColors.neutral400,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              if (package.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  package.description!,
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 13, height: 1.5),
                ),
              ],
              if (package.features != null && package.features!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Yang kamu dapat',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final feature in package.features!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, size: 16, color: AppColors.success600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (package.materi != null && package.materi!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Materi yang dicakup',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final materi in package.materi!)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          materi,
                          style: const TextStyle(color: AppColors.neutral700, fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: isOwned
                    ? const _OwnedBadge()
                    : FilledButton(
                        onPressed: isBuying ? null : onBeli,
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Beli Sekarang'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'Belum ada paket untuk kategori ini.',
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
EOF_KATSCREEN

cat > lib/core/router/app_router.dart << 'EOF_ROUTER'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_form_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/akun/presentation/screens/edit_profil_screen.dart';
import '../../features/akun/presentation/screens/ganti_password_screen.dart';
import '../../features/beranda/presentation/screens/analisis_performa_screen.dart';
import '../../features/enrollment/presentation/screens/paket_saya_screen.dart';
import '../../features/katalog/data/models/package_model.dart';
import '../../features/katalog/presentation/screens/katalog_screen.dart';
import '../../features/katalog/presentation/screens/tryout_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/subscription/presentation/screens/langganan_screen.dart';
import '../../features/transaksi/presentation/screens/checkout_webview_screen.dart';
import '../../features/transaksi/presentation/screens/riwayat_transaksi_screen.dart';
import '../../features/transaksi/presentation/screens/transaksi_detail_screen.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/register/form' ||
          loc == '/check-email' ||
          loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash) return '/login';
          if (isAuthRoute) return null;
          return '/login';
        },
        authenticated: (_) {
          if (isSplash || isAuthRoute) return '/home';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/register/form',
        builder: (_, __) => const RegisterFormScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/akun/edit-profil',
        builder: (_, __) => const EditProfilScreen(),
      ),
      GoRoute(
        path: '/akun/ganti-password',
        builder: (_, __) => const GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
      ),
      GoRoute(
        path: '/transaksi',
        builder: (_, __) => const RiwayatTransaksiScreen(),
      ),
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransaksiDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/langganan',
        builder: (_, __) => const LangganganScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final args = state.extra as CheckoutArgs;
          return CheckoutWebViewScreen(transactionId: args.transactionId, snapToken: args.snapToken);
        },
      ),
      GoRoute(
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
      ),
      GoRoute(
        path: '/katalog',
        builder: (context, state) {
          final filter = state.extra as PackageType?;
          return KatalogScreen(initialFilter: filter);
        },
      ),
      GoRoute(
        path: '/latihan-soal',
        builder: (_, __) => const LatihanKategoriScreen(),
      ),
      GoRoute(
        path: '/latihan-soal/kategori/:taxonomyId',
        builder: (context, state) {
          final taxonomyId = int.parse(state.pathParameters['taxonomyId']!);
          final categoryName = state.extra as String?;
          return LatihanTopikScreen(taxonomyId: taxonomyId, categoryName: categoryName);
        },
      ),
      GoRoute(
        path: '/latihan-soal/topik/:topicId',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['topicId']!);
          final topicName = state.extra as String?;
          return LatihanRoadmapScreen(topicId: topicId, topicName: topicName);
        },
      ),
      GoRoute(
        path: '/paket/:packageId/exams',
        builder: (context, state) {
          final packageId = int.parse(state.pathParameters['packageId']!);
          return ExamListScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/exams/:examId/summary',
        builder: (context, state) {
          final examId = int.parse(state.pathParameters['examId']!);
          return ExamSummaryScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamAttemptScreen(attemptId: attemptId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId/review',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamReviewScreen(attemptId: attemptId);
        },
      ),
    ],
  );
}

EOF_ROUTER

cat > lib/features/katalog/presentation/screens/tryout_screen.dart << 'EOF_TRYOUT'
// lib/features/katalog/presentation/screens/tryout_screen.dart
//
// Tab Tryout -- reuse enrollmentNotifierProvider yang sama dengan Paket Saya
// (cache /my-packages, TIDAK ada network call baru di sini), difilter ke
// package.type == PackageType.reguler saja. Tap paket aktif -> daftar exam
// paket itu (ExamListScreen yang sudah ada, tidak diubah).
//
// PENTING: fitur ini SENGAJA tidak punya logika exam_batch_id sama sekali --
// reuse Exam Engine persis seperti Latihan Fokus. Lihat catatan §6 di
// dokumen status project untuk alasannya (exam_batch_id tidak tersambung ke
// flow start-exam manapun, baik web maupun mobile).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../data/models/package_model.dart';

class TryoutScreen extends ConsumerWidget {
  const TryoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(enrollmentNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Tryout'),
      ),
      body: enrollmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.read(enrollmentNotifierProvider.notifier).refresh(),
        ),
        data: (enrollments) {
          final tryoutEnrollments =
              enrollments.where((e) => e.package.type == PackageType.reguler).toList();

          if (tryoutEnrollments.isEmpty) return const _EmptyState();

          final active = tryoutEnrollments.where((e) => e.isActive).toList();
          final expired = tryoutEnrollments.where((e) => !e.isActive).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(enrollmentNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (active.isNotEmpty) ...[
                  const _SectionTitle(title: 'Aktif'),
                  const SizedBox(height: 12),
                  for (final e in active) ...[
                    _TryoutCard(enrollment: e),
                    const SizedBox(height: 12),
                  ],
                ],
                if (expired.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle(title: 'Kedaluwarsa'),
                  const SizedBox(height: 12),
                  for (final e in expired) ...[
                    _TryoutCard(enrollment: e),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          );
        },
      ),
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
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TryoutCard extends StatelessWidget {
  const _TryoutCard({required this.enrollment});
  final EnrollmentModel enrollment;

  String get _periodLabel {
    if (enrollment.isLifetime) return 'Berlaku selamanya';
    final start = enrollment.startDate;
    final end = enrollment.endDate;
    if (start == null && end == null) return '-';
    return '${start ?? '-'} s.d. ${end ?? '-'}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = enrollment.isActive;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: enrollment.package.bannerImageUrl != null
                    ? Image.network(
                        enrollment.package.bannerImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.neutral100,
                          alignment: Alignment.center,
                          child: const Icon(Icons.assignment_outlined, color: AppColors.neutral400),
                        ),
                      )
                    : Container(
                        color: AppColors.neutral100,
                        alignment: Alignment.center,
                        child: const Icon(Icons.assignment_outlined, color: AppColors.neutral400),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              enrollment.package.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.neutral900,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusBadge(isActive: isActive),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _periodLabel,
                        style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isActive) ...[
            const Divider(height: 1, color: AppColors.neutral200),
            InkWell(
              onTap: () => context.push('/paket/${enrollment.package.id}/exams'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lihat Tryout',
                      style: TextStyle(
                        color: AppColors.brand600,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: AppColors.brand600, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success50 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Kedaluwarsa',
        style: TextStyle(
          color: isActive ? AppColors.success700 : AppColors.neutral500,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum punya paket Tryout',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Beli paket Tryout untuk mulai simulasi ujian.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/katalog', extra: PackageType.reguler),
              child: const Text('Lihat Katalog Tryout'),
            ),
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
              'Gagal memuat paket Tryout',
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

EOF_TRYOUT

echo 'Katalog paket beli-baru + konsolidasi formatRupiah + fix invalidate enrollment diterapkan.'
