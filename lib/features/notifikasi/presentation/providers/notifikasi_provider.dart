// lib/features/notifikasi/presentation/providers/notifikasi_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../beranda/presentation/providers/beranda_provider.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifikasi_repository.dart';

export '../../data/models/notification_model.dart';

part 'notifikasi_provider.g.dart';

@riverpod
class NotifikasiNotifier extends _$NotifikasiNotifier {
  @override
  Future<List<NotificationModel>> build() {
    return ref.watch(notifikasiRepositoryProvider).getNotifications();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Tandai 1 notifikasi dibaca. Update optimis di list lokal dulu supaya
  /// UI langsung responsif, baru panggil API. Kalau API gagal (mis.
  /// offline), rollback -- supaya UI tidak "bohong" soal status dibaca.
  /// Badge unread di Beranda ikut di-invalidate biar angkanya sinkron
  /// tanpa user harus keluar-masuk layar Beranda.
  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final index = current.indexWhere((n) => n.id == id);
    if (index == -1 || current[index].isRead) return;

    final previous = current[index];
    final optimistic = [...current];
    optimistic[index] = previous.copyWith(readAt: DateTime.now());
    state = AsyncData(optimistic);

    try {
      await ref.read(notifikasiRepositoryProvider).markAsRead(id);
      ref.invalidate(berandaNotifierProvider);
    } catch (_) {
      final rolledBack = [...optimistic];
      rolledBack[index] = previous;
      state = AsyncData(rolledBack);
    }
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.every((n) => n.isRead)) return;

    final now = DateTime.now();
    final optimistic = [
      for (final n in current) n.isRead ? n : n.copyWith(readAt: now),
    ];
    state = AsyncData(optimistic);

    try {
      await ref.read(notifikasiRepositoryProvider).markAllAsRead();
      ref.invalidate(berandaNotifierProvider);
    } catch (_) {
      state = AsyncData(current);
    }
  }
}
