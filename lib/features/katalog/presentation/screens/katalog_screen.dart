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
import '../../data/models/promo_model.dart';
import '../providers/katalog_provider.dart';
import '../widgets/promo_code_field.dart';

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

  Future<void> _handleBeli({String? promoCode}) async {
    setState(() => _isBuying = true);
    try {
      final transaction = await ref
          .read(transaksiRepositoryProvider)
          .checkoutPackage(widget.package.id, promoCode: promoCode);
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
        onBeli: (promoCode) {
          Navigator.of(sheetContext).pop();
          _handleBeli(promoCode: promoCode);
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

class _PackageDetailSheet extends StatefulWidget {
  const _PackageDetailSheet({
    required this.package,
    required this.isOwned,
    required this.isBuying,
    required this.onBeli,
  });

  final PackageModel package;
  final bool isOwned;
  final bool isBuying;

  /// Dipanggil dengan kode promo yang sedang diterapkan (null kalau tidak
  /// ada) begitu tombol "Beli Sekarang" ditekan.
  final ValueChanged<String?> onBeli;

  @override
  State<_PackageDetailSheet> createState() => _PackageDetailSheetState();
}

class _PackageDetailSheetState extends State<_PackageDetailSheet> {
  PromoValidationResult? _promo;

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final isOwned = widget.isOwned;
    final isBuying = widget.isBuying;
    final onBeli = widget.onBeli;
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
                    formatRupiah(_promo?.finalAmount ?? package.effectivePrice),
                    style: const TextStyle(
                      color: AppColors.brand600,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Kalau promo diterapkan, yang dicoret adalah harga SEBELUM
                  // promo (effectivePrice, yang sudah termasuk discount_price
                  // paket kalau ada) -- bukan package.price mentah, supaya
                  // tidak terlihat seperti diskon dobel yang salah hitung.
                  if (_promo != null || package.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatRupiah(_promo != null ? package.effectivePrice : package.price),
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
              if (!isOwned) ...[
                const SizedBox(height: 20),
                const Text(
                  'Kode Promo',
                  style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                PromoCodeField(
                  packageId: package.id,
                  onResultChanged: (result) => setState(() => _promo = result),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: isOwned
                    ? const _OwnedBadge()
                    : FilledButton(
                        onPressed: isBuying ? null : () => onBeli(_promo?.promo.code),
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

