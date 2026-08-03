// lib/features/transaksi/presentation/screens/transaksi_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/transaksi_repository.dart';
import '../providers/transaksi_provider.dart';
import 'checkout_webview_screen.dart';
import 'transaksi_format.dart';

class TransaksiDetailScreen extends ConsumerWidget {
  const TransaksiDetailScreen({super.key, required this.transactionId});
  final int transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(transaksiDetailProvider(transactionId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Detail Transaksi'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Gagal memuat detail transaksi',
                  style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(transaksiDetailProvider(transactionId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (transaction) => _DetailBody(transaction: transaction),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.transaction});
  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
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
                      transaction.itemName,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusChip(status: transaction.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                formatTanggal(transaction.createdAt),
                style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
              ),
              const Divider(height: 24, color: AppColors.neutral200),
              _InfoRow(label: 'No. Invoice', value: transaction.invoiceNumber ?? '-'),
              const SizedBox(height: 10),
              _InfoRow(label: 'ID Order', value: transaction.midtransOrderId ?? '-'),
              if (transaction.paymentMethod != null) ...[
                const SizedBox(height: 10),
                _InfoRow(label: 'Metode Pembayaran', value: transaction.paymentMethod!),
              ],
              if (transaction.paidAt != null) ...[
                const SizedBox(height: 10),
                _InfoRow(label: 'Dibayar', value: formatTanggal(transaction.paidAt)),
              ],
              if (transaction.isPending && transaction.expiresAt != null) ...[
                const SizedBox(height: 10),
                _InfoRow(label: 'Batas Bayar', value: formatTanggal(transaction.expiresAt)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rincian Pembayaran',
                style: TextStyle(color: AppColors.neutral900, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Harga',
                value: formatRupiah(transaction.amount + transaction.discountAmount),
              ),
              if (transaction.discountAmount > 0) ...[
                const SizedBox(height: 10),
                _InfoRow(
                  label: transaction.promo != null ? 'Promo (${transaction.promo!.code})' : 'Diskon',
                  value: '-${formatRupiah(transaction.discountAmount)}',
                  valueColor: AppColors.success700,
                ),
              ],
              const Divider(height: 24, color: AppColors.neutral200),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(color: AppColors.neutral900, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatRupiah(transaction.total),
                    style: const TextStyle(color: AppColors.brand600, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (transaction.isPending) ...[
          const SizedBox(height: 16),
          _ResumePaymentButton(transactionId: transaction.id),
        ],
      ],
    );
  }
}

/// Tombol "Lanjutkan Pembayaran" -- state loading-nya lokal (ConsumerStatefulWidget)
/// karena ini aksi sekali-tekan, bukan data yang perlu di-watch lewat provider.
class _ResumePaymentButton extends ConsumerStatefulWidget {
  const _ResumePaymentButton({required this.transactionId});
  final int transactionId;

  @override
  ConsumerState<_ResumePaymentButton> createState() => _ResumePaymentButtonState();
}

class _ResumePaymentButtonState extends ConsumerState<_ResumePaymentButton> {
  bool _isLoading = false;

  Future<void> _resume() async {
    setState(() => _isLoading = true);
    try {
      final snapToken = await ref.read(transaksiRepositoryProvider).resumeTransaction(widget.transactionId);
      if (!mounted) return;

      await context.push<CheckoutResult>(
        '/checkout',
        extra: CheckoutArgs(transactionId: widget.transactionId, snapToken: snapToken),
      );
      // CheckoutWebViewScreen sudah invalidate transaksiDetailProvider
      // sendiri sebelum pop -- tidak perlu refresh manual lagi di sini.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _resume,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.payment, size: 18),
        label: Text(_isLoading ? 'Menyiapkan pembayaran...' : 'Lanjutkan Pembayaran'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
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
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.neutral500, fontSize: 12.5)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? AppColors.neutral900,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

