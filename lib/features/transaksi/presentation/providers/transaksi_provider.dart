// lib/features/transaksi/presentation/providers/transaksi_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaksi_repository.dart';

export '../../data/models/transaction_model.dart';

part 'transaksi_provider.g.dart';

@riverpod
class TransaksiNotifier extends _$TransaksiNotifier {
  @override
  Future<List<TransactionModel>> build() {
    return ref.watch(transaksiRepositoryProvider).getTransactions();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Detail 1 transaksi. Family terpisah dari list -- kalau user masuk lewat
/// deep link/notifikasi (belum pernah lewat layar riwayat), detail tetap
/// bisa diambil langsung tanpa bergantung pada TransaksiNotifier sudah
/// ter-load atau belum.
@riverpod
Future<TransactionModel> transaksiDetail(TransaksiDetailRef ref, int id) {
  return ref.watch(transaksiRepositoryProvider).getTransactionDetail(id);
}

