// lib/features/subscription/presentation/screens/langganan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../katalog/data/models/promo_model.dart';
import '../../../katalog/presentation/widgets/promo_code_field.dart';
import '../../../transaksi/data/repositories/transaksi_repository.dart';
import '../../../transaksi/presentation/screens/checkout_webview_screen.dart';
import '../providers/subscription_provider.dart';
import 'subscription_format.dart';

class LangganganScreen extends ConsumerWidget {
  const LangganganScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Langganan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(mySubscriptionNotifierProvider.notifier).refresh(),
            ref.read(subscriptionPlansNotifierProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: const [
            _MySubscriptionSection(),
            SizedBox(height: 24),
            _PlansSection(),
          ],
        ),
      ),
    );
  }
}

class _MySubscriptionSection extends ConsumerWidget {
  const _MySubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(mySubscriptionNotifierProvider);

    return subAsync.when(
      loading: () => Container(
        height: 88,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Gagal memuat status langganan', style: TextStyle(color: AppColors.neutral600, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => ref.read(mySubscriptionNotifierProvider.notifier).refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (subscription) {
        if (subscription == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.neutral500, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kamu belum berlangganan. Pilih paket di bawah untuk akses penuh.',
                    style: TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }

        final plan = subscription.plan;
        final coverageLabel = plan.isFixedProgram
            ? plan.program?.name ?? '-'
            : '${subscription.coveredProgramIds.length} program dipilih';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brand600, AppColors.brand500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Langganan Aktif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                plan.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Mencakup: $coverageLabel',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (subscription.endDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Berlaku sampai ${formatTanggalSingkat(subscription.endDate)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlansSection extends ConsumerWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Paket Langganan',
          style: TextStyle(color: AppColors.neutral900, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        plansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Gagal memuat paket langganan', style: TextStyle(color: AppColors.neutral600, fontSize: 12.5)),
                ),
                TextButton(
                  onPressed: () => ref.read(subscriptionPlansNotifierProvider.notifier).refresh(),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Belum ada paket langganan yang tersedia saat ini.',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                ),
              );
            }

            return Column(
              children: [
                for (final plan in plans) ...[
                  _PlanCard(plan: plan),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlanModel plan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showPlanDetail(context, plan),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: plan.isFeatured ? AppColors.brand500 : AppColors.neutral200, width: plan.isFeatured ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          style: const TextStyle(color: AppColors.neutral900, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (plan.isFeatured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold100, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Populer', style: TextStyle(color: AppColors.gold600, fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if (plan.tagline != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      plan.tagline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${formatRupiah(plan.price)} / ${formatDurasi(plan.durationDays)}',
                    style: const TextStyle(color: AppColors.brand600, fontSize: 13.5, fontWeight: FontWeight.w700),
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

void _showPlanDetail(BuildContext context, SubscriptionPlanModel plan) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _PlanDetailSheet(plan: plan),
  );
}

class _PlanDetailSheet extends ConsumerStatefulWidget {
  const _PlanDetailSheet({required this.plan});
  final SubscriptionPlanModel plan;

  @override
  ConsumerState<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends ConsumerState<_PlanDetailSheet> {
  bool _isCheckingOut = false;
  PromoValidationResult? _promo;

  Future<void> _handleBerlangganan() async {
    final plan = widget.plan;

    // Plan multi-select (program_slot_count terisi) butuh UI pemilihan
    // program yang belum dibangun -- daripada checkout dengan program_ids
    // asal/kosong dan kena 422 membingungkan, kasih tau jelas di sini.
    if (!plan.isFixedProgram) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Belum tersedia'),
          content: Text(
            'Plan ini butuh memilih ${plan.programSlotCount} program terlebih dulu -- fitur pemilihan program masih dalam pengembangan.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Oke')),
          ],
        ),
      );
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      final transaction = await ref
          .read(transaksiRepositoryProvider)
          .checkoutPlan(plan.id, promoCode: _promo?.promo.code);
      final token = transaction.snapToken;
      if (token == null) throw Exception('Token pembayaran tidak tersedia. Coba lagi.');

      if (!mounted) return;
      // Sengaja TIDAK nutup bottom sheet dulu -- context.push jalan di atas
      // sheet yang masih ada (sheet-nya cuma ketutup visual, bukan
      // di-dispose), begitu CheckoutWebViewScreen pop balik baru sheet ini
      // ditutup manual di bawah. Menghindari masalah context defunct kalau
      // sheet ditutup duluan sebelum push selesai.
      await context.push<CheckoutResult>(
        '/checkout',
        extra: CheckoutArgs(transactionId: transaction.id, snapToken: token),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.neutral200, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(plan.name, style: const TextStyle(color: AppColors.neutral900, fontSize: 17, fontWeight: FontWeight.w700)),
            if (plan.tagline != null) ...[
              const SizedBox(height: 4),
              Text(plan.tagline!, style: const TextStyle(color: AppColors.neutral500, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${formatRupiah(_promo?.finalAmount ?? plan.price)} / ${formatDurasi(plan.durationDays)}',
                  style: const TextStyle(color: AppColors.brand600, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (_promo != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(plan.price),
                    style: const TextStyle(
                      color: AppColors.neutral400,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            if (plan.description != null) ...[
              const SizedBox(height: 12),
              Text(plan.description!, style: const TextStyle(color: AppColors.neutral700, fontSize: 13, height: 1.5)),
            ],
            if (plan.features != null && plan.features!.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final feature in plan.features!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(feature, style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Kode Promo',
              style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            PromoCodeField(
              planId: plan.id,
              onResultChanged: (result) => setState(() => _promo = result),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCheckingOut ? null : _handleBerlangganan,
                icon: _isCheckingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(_isCheckingOut ? 'Menyiapkan pembayaran...' : 'Berlangganan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

