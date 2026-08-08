import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../subscription/data/models/subscription_plan_model.dart';
import '../providers/beranda_provider.dart';

/// Redesign Agustus 2026 -- struktur baru disepakati bersama Fajar supaya:
///   1. User gampang pilih jalur "langganan" (produk utama) vs "beli exam
///      terpisah" (produk kedua) -- lihat _UpgradeLanggananCard di bawah.
///   2. User gampang lihat progres -- _ProgressSection (ringkasan skor +
///      breakdown per section), bukan cuma 2 angka datar seperti sebelumnya.
///   3. User gampang lihat "tugas" mereka -- _TugasSelanjutnyaSection,
///      dari performance.topRecommendations (topik lemah yang perlu
///      dilatih), yang SEBELUMNYA di-fetch tapi tidak pernah ditampilkan
///      di Beranda sama sekali.
/// TIDAK ADA endpoint baru -- semua section baru pakai data yang sudah
/// di-fetch BerandaRepository, kecuali subscriptionPlans (GET
/// /subscription-plans) yang di-reuse dari SubscriptionRepository yang
/// sudah ada (dipakai LanggananScreen), bukan panggilan API baru dari sisi
/// backend, dan cuma dipanggil kalau user belum berlangganan.
class BerandaScreen extends ConsumerWidget {
  const BerandaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berandaAsync = ref.watch(berandaNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
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
                const SizedBox(height: 20),
                _ContinueCard(exam: data.continueExam),

                // ---------- Tugas Selanjutnya ----------
                if (data.performance.topRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: 'Tugas Selanjutnya',
                    actionLabel: data.performance.topRecommendations.length > 3 ? 'Lihat semua' : null,
                    onAction: () => context.push('/analisis-performa'),
                  ),
                  const SizedBox(height: 12),
                  _TugasSelanjutnyaSection(
                    recommendations: data.performance.topRecommendations.take(3).toList(),
                  ),
                ],

                // ---------- Latihan & Progres (digabung) ----------
                // SEBELUMNYA 2 section terpisah ("Progres Kamu" &
                // "Latihan & Try Out") dengan header + jarak sendiri-
                // sendiri -- terasa terpecah padahal isinya saling
                // berkaitan langsung (grid akses cepat DAN breakdown skor
                // sama-sama soal "belajar di mana selanjutnya"). Digabung
                // 1 section: grid dulu (aksi utama), breakdown skor di
                // bawahnya (konteks pendukung), 1 header saja.
                const SizedBox(height: 28),
                _SectionHeader(
                  title: 'Latihan & Progres',
                  actionLabel: 'Detail',
                  onAction: () => context.push('/analisis-performa'),
                ),
                const SizedBox(height: 12),
                const _PracticeGrid(),
                const SizedBox(height: 16),
                if (data.performance.sections.isNotEmpty) ...[
                  _StatsRow(averageScore: data.averageScore, rank: data.rank),
                  const SizedBox(height: 12),
                  _ProgressSectionsRow(sections: data.performance.sections),
                ] else if (data.performance.cta != null)
                  _StartPracticeCta(cta: data.performance.cta!),

                // ---------- Upgrade Langganan (kondisional) ----------
                if (data.subscriptionPlans.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _UpgradeLanggananCard(plans: data.subscriptionPlans),
                ],

                // ---------- Rekomendasi Paket (jalur beli-terpisah) ----------
                if (data.recommendedPackages.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(
                    title: data.hasActiveSubscription ? 'Paket Tambahan' : 'Mulai dari Paket Ini',
                  ),
                  const SizedBox(height: 12),
                  _RecommendedPackages(packages: data.recommendedPackages),
                ],

                if (data.promoBanners.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _PromoCarousel(banners: data.promoBanners),
                ],

                const SizedBox(height: 24),
                _LeaderboardPreview(rank: data.rank),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header section generik dipakai semua section baru -- judul + aksi kanan
/// opsional (mis. "Lihat semua" / "Detail"). Dulu tiap section nulis Text
/// judul sendiri-sendiri (_SectionTitle) tanpa slot aksi sama sekali.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.neutral900,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                      color: AppColors.brand600,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.brand600, size: 16),
                ],
              ),
            ),
          ),
      ],
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand500, AppColors.brand700],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand500.withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.workspace_premium, color: AppColors.gold600, size: 10),
                          const SizedBox(width: 3),
                          Text(
                            subscriptionPackageName ?? 'Premium',
                            style: const TextStyle(
                              color: AppColors.gold600,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

/// Kartu dekoratif -- 2 lingkaran semi-transparan di pojok kanan-bawah,
/// bukan flat solid color polos. Tidak pakai image asset (butuh bundling
/// baru); cukup shape sederhana buat kesan "berlapis".
class _DecorativeCircles extends StatelessWidget {
  const _DecorativeCircles();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -50,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.exam});
  final ContinueExamData? exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FIX BUG: sebelumnya pakai `exam != null` untuk nentuin "Lanjutkan"
    // vs "Mulai" -- SALAH, karena `exam` (dari /my-exams/latest-attempted)
    // hampir selalu terisi (backend fallback ke exam rekomendasi kalau
    // belum ada progress apa pun, lihat catatan panjang di
    // BerandaApiService.getLatestAttemptedExamId()). Akibatnya begitu user
    // baru saja MENYELESAIKAN ujian, card ini tetap bilang "Lanjutkan
    // Belajar" ke exam yang sama -- padahal sudah beres, tidak ada yang
    // perlu dilanjutkan. Sinyal yang benar: inProgressAttemptId != null,
    // yang cuma keisi kalau BENAR ada attempt yang belum selesai.
    final hasExam = exam != null;
    final isResuming = exam?.inProgressAttemptId != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand500, AppColors.brand700],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand500.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const _DecorativeCircles(),
          Padding(
            padding: const EdgeInsets.all(20),
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
                        isResuming ? Icons.play_circle_outline : Icons.bolt_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isResuming ? 'Lanjutkan Belajar' : 'Mulai Belajar',
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
                if (isResuming) ...[
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
                    // masuk ke screen ringkasan exam, entah itu mulai baru
                    // (isResuming false) atau lanjut attempt in-progress
                    // (isResuming true) -- ExamSummaryScreen yang urus keduanya.
                    // !hasExam -> belum ada exam untuk direkomendasikan sama
                    // sekali, arahkan ke tab Latihan.
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
                    child: Text(
                      !hasExam ? 'Cari Latihan' : (isResuming ? 'Lanjutkan' : 'Mulai'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section "Tugas Selanjutnya" -- dari performance.topRecommendations.
/// Navigasi pakai pola PERSIS yang sama dengan _RecommendationCard di
/// AnalisisPerformaScreen (recommendation.topicId ke roadmap topik, BUKAN
/// recommendation.practiceLink -- lihat catatan di sana soal practice_link
/// belum match route app ini).
class _TugasSelanjutnyaSection extends StatelessWidget {
  const _TugasSelanjutnyaSection({required this.recommendations});
  final List<TopRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < recommendations.length; i++) ...[
          if (i != 0) const SizedBox(height: 10),
          _TugasCard(recommendation: recommendations[i]),
        ],
      ],
    );
  }
}

/// Warna badge dibedakan per section (TWK/TIU/TKP) -- bukan cuma dekorasi,
/// tapi bantu user memindai sekilas "tugas ini dari subtes mana" kalau
/// campuran >1 section muncul dalam satu strip. Fallback abu-abu netral
/// untuk section code di luar 3 ini (jaga-jaga kalau backend nambah kode
/// baru suatu saat).
(Color, Color) _sectionAccentColor(String sectionCode) {
  switch (sectionCode) {
    case 'TWK':
      return (AppColors.info600, AppColors.info100);
    case 'TIU':
      return (AppColors.violet600, AppColors.violet100);
    case 'TKP':
      return (AppColors.teal600, AppColors.teal100);
    default:
      return (AppColors.neutral600, AppColors.neutral100);
  }
}

class _TugasCard extends StatelessWidget {
  const _TugasCard({required this.recommendation});
  final TopRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final (accent, accentBg) = _sectionAccentColor(recommendation.sectionCode);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.bolt_outlined, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          recommendation.topicName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recommendation.sectionCode,
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recommendation.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.neutral500, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recommendation.suggestedQuestionCount} soal disarankan',
                    style: const TextStyle(
                      color: AppColors.gold600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

/// CTA state=no_attempts -- performance.cta HANYA ada kalau backend
/// mengirim state itu (lihat catatan di model PerformanceSummary). Belum
/// pernah ditampilkan di Beranda sebelumnya, cuma dipakai di
/// AnalisisPerformaScreen (_NoAttemptsState) -- ditambahkan di sini juga
/// supaya user baru langsung lihat ajakan mulai tanpa harus masuk ke tab
/// Progres dulu.
class _StartPracticeCta extends StatelessWidget {
  const _StartPracticeCta({required this.cta});
  final PerformanceCta cta;

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
      child: Row(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.brand500, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cta.message,
              style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            // action_link mentah dari backend belum tentu match route app
            // ini (pola sama seperti practice_link di TopRecommendation) --
            // arahkan ke tab Latihan, jalur paling aman buat mulai try-out
            // pertama.
            onPressed: () => context.push('/tryout'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand600,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
            ),
            child: const Text('Mulai', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Carousel promo dari /promos/active.
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

/// Ikon custom gambar sendiri (CustomPainter), BUKAN Material Icons --
/// bentuknya dua-lapis (warna solid + warna transparan di belakang) supaya
/// ada kesan "berlapis"/dekoratif, bukan cuma outline sederhana kayak
/// Icons.topic_outlined dkk. Ukuran painting selalu relatif ke `size`
/// (bukan angka fix) supaya tetap proporsional kalau suatu saat dipakai
/// di ukuran lain.
class _StackedTopicIconPainter extends CustomPainter {
  const _StackedTopicIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final back = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.28, w * 0.62, h * 0.50),
      Radius.circular(w * 0.09),
    );
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.14, w * 0.62, h * 0.50),
      Radius.circular(w * 0.09),
    );
    canvas.drawRRect(back, Paint()..color = color.withOpacity(0.35));
    canvas.drawRRect(front, Paint()..color = color);

    final line = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.40, h * 0.33), Offset(w * 0.76, h * 0.33), line);
    canvas.drawLine(Offset(w * 0.40, h * 0.47), Offset(w * 0.62, h * 0.47), line);
  }

  @override
  bool shouldRepaint(covariant _StackedTopicIconPainter oldDelegate) => oldDelegate.color != color;
}

class _StopwatchIconPainter extends CustomPainter {
  const _StopwatchIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w * 0.5, h * 0.58);
    final radius = w * 0.36;

    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.12), width: w * 0.26, height: h * 0.14),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = color.withOpacity(0.55),
    );
    final hand = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx + radius * 0.48, center.dy - radius * 0.42), hand);
    canvas.drawCircle(center, w * 0.05, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StopwatchIconPainter oldDelegate) => oldDelegate.color != color;
}

class _TrendUpIconPainter extends CustomPainter {
  const _TrendUpIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const heights = [0.34, 0.56, 0.82];
    final barWidth = w * 0.18;
    final gap = w * 0.10;
    var x = w * 0.08;
    for (var i = 0; i < heights.length; i++) {
      final barH = h * heights[i];
      final rect = Rect.fromLTWH(x, h * 0.88 - barH, barWidth, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w * 0.045)),
        Paint()..color = color.withOpacity(0.45 + i * 0.2),
      );
      x += barWidth + gap;
    }
    final dot = Offset(x - gap - barWidth / 2, h * 0.88 - h * heights.last - h * 0.10);
    canvas.drawCircle(dot, w * 0.065, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendUpIconPainter oldDelegate) => oldDelegate.color != color;
}

/// Grid akses cepat, 3 item, tiap item push langsung ke rute tujuannya.
///
/// Warna badge SENGAJA dibedakan per tile (bukan brand500 semua seperti
/// draft pertama) -- brand-maroon dicadangkan untuk elemen core (Continue
/// Card, tombol utama), grid ini pakai palet aksen (info/gold/success)
/// supaya tidak terasa monokrom. Ikon juga custom-painted (bukan Material
/// Icons) supaya tidak terasa generik/kaku.
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  // Tipe list dieksplisitkan (bukan dibiarkan diinferensi dari literal) --
  // tiap entri punya `painter` yang tear-off ke CLASS PAINTER BEDA
  // (_StackedTopicIconPainter, _StopwatchIconPainter, _TrendUpIconPainter),
  // jadi Dart butuh tipe target eksplisit `CustomPainter Function(Color)`
  // supaya masing-masing constructor tear-off itu di-upcast konsisten,
  // bukan coba infer least-upper-bound sendiri dari 3 tipe berbeda.
  static const List<
      ({
        CustomPainter Function(Color) painter,
        String title,
        String subtitle,
        String route,
        Color color,
        Color bgColor,
      })> _items = [
    (
      painter: _StackedTopicIconPainter.new,
      title: 'Latihan Soal per Topik',
      subtitle: 'Susun roadmap topik',
      route: '/latihan-soal',
      color: AppColors.info600,
      bgColor: AppColors.info100,
    ),
    (
      painter: _StopwatchIconPainter.new,
      title: 'Tryout',
      subtitle: 'Simulasi CAT penuh',
      route: '/tryout',
      color: AppColors.gold600,
      bgColor: AppColors.gold100,
    ),
    (
      painter: _TrendUpIconPainter.new,
      title: 'Analisis Performa',
      subtitle: 'Lihat progres belajarmu',
      route: '/analisis-performa',
      color: AppColors.success600,
      bgColor: AppColors.success50,
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

  Widget _buildTile(
    BuildContext context,
    ({
      CustomPainter Function(Color) painter,
      String title,
      String subtitle,
      String route,
      Color color,
      Color bgColor,
    }) item,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(item.route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(painter: item.painter(item.color)),
            ),
            const SizedBox(height: 12),
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

/// Bentuk pita diskon bergaya e-commerce.
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
    const notch = 7.0;
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
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neutral900.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

/// Breakdown per section (TWK/TIU/TKP dst) -- data dari
/// performance.sections yang SEBELUMNYA di-fetch tapi cuma dipakai di
/// AnalisisPerformaScreen (versi penuh dengan breakdown topik). Versi di
/// sini sengaja ringkas (tanpa daftar topik) -- tap kartu untuk lihat
/// detail penuh, bukan duplikasi seluruh _SectionCard di AnalisisPerforma.
class _ProgressSectionsRow extends StatelessWidget {
  const _ProgressSectionsRow({required this.sections});
  final List<PerformanceSection> sections;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _ProgressSectionCard(section: sections[index]),
      ),
    );
  }
}

class _ProgressSectionCard extends StatelessWidget {
  const _ProgressSectionCard({required this.section});
  final PerformanceSection section;

  @override
  Widget build(BuildContext context) {
    // Progress bar: kalau ada ambang lulus, pakai current_score/min_passing
    // (jadi 100% persis di titik lulus). Kalau tidak ada ambang, fallback
    // ke current_score/100 -- asumsi skor 0-100, konsisten dengan
    // penampilan skor lain di layar ini (mis. _StatCard averageScore).
    final progress = section.minPassingScore != null && section.minPassingScore! > 0
        ? (section.currentScore / section.minPassingScore!).clamp(0.0, 1.0)
        : (section.currentScore / 100).clamp(0.0, 1.0);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/analisis-performa'),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  section.isPassed ? Icons.check_circle : Icons.schedule,
                  color: section.isPassed ? AppColors.success600 : AppColors.neutral400,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.neutral100,
                valueColor: AlwaysStoppedAnimation(
                  section.isPassed ? AppColors.success600 : AppColors.gold600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.minPassingScore != null
                  ? '${section.currentScore.toStringAsFixed(0)} / ${section.minPassingScore}'
                  : section.currentScore.toStringAsFixed(0),
              style: const TextStyle(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu upsell "Upgrade ke Langganan" -- HANYA dirender kalau
/// BerandaData.subscriptionPlans tidak kosong (artinya user belum
/// berlangganan aktif, lihat BerandaRepository.getBerandaData()). Plan
/// yang ditonjolkan: is_featured pertama, fallback plan pertama di list
/// kalau tidak ada yang featured.
class _UpgradeLanggananCard extends StatelessWidget {
  const _UpgradeLanggananCard({required this.plans});
  final List<SubscriptionPlanModel> plans;

  @override
  Widget build(BuildContext context) {
    final featured = plans.firstWhere(
      (p) => p.isFeatured,
      orElse: () => plans.first,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/langganan'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gold600, AppColors.brand600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold600.withOpacity(0.30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            const _DecorativeCircles(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Akses Semua Try Out',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    featured.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (featured.tagline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      featured.tagline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatRupiah(featured.price),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ ${formatDurasi(featured.durationDays)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/langganan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.brand700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(plans.length > 1 ? 'Lihat Semua Paket Langganan' : 'Lihat Detail'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardPreview extends ConsumerWidget {
  const _LeaderboardPreview({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => ref.read(selectedTabIndexProvider.notifier).state = 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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