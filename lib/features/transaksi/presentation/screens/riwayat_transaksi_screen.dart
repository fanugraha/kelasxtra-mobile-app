// lib/features/transaksi/presentation/screens/riwayat_transaksi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/transaksi_provider.dart';
import 'transaksi_format.dart';

class RiwayatTransaksiScreen extends ConsumerWidget {
  const RiwayatTransaksiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaksiAsync = ref.watch(transaksiNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Riwayat Transaksi'),
      ),
      body: transaksiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.read(transaksiNotifierProvider.notifier).refresh(),
        ),
        data: (transactions) {
          if (transactions.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () => ref.read(transaksiNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _TransactionCard(transaction: transactions[index]),
            ),
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/transaksi/${transaction.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatTanggal(transaction.createdAt),
                    style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatRupiah(transaction.total),
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status: transaction.status),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      TransactionStatus.success => (AppColors.success50, AppColors.success700, 'Berhasil'),
      TransactionStatus.pending => (AppColors.gold100, AppColors.gold600, 'Menunggu'),
      TransactionStatus.failed => (AppColors.danger50, AppColors.danger700, 'Gagal'),
      TransactionStatus.expired => (AppColors.neutral100, AppColors.neutral500, 'Kedaluwarsa'),
      TransactionStatus.refunded => (AppColors.neutral100, AppColors.neutral600, 'Refund'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
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
            const Icon(Icons.receipt_long_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada transaksi',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Riwayat pembelian paket dan langganan kamu akan muncul di sini.',
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
              'Gagal memuat riwayat transaksi',
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

