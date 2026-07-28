// lib/features/notifikasi/presentation/screens/notifikasi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/notifikasi_provider.dart';

class NotifikasiScreen extends ConsumerWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notifikasiNotifierProvider);
    final hasUnread = notifAsync.valueOrNull?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifikasi'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () =>
                  ref.read(notifikasiNotifierProvider.notifier).markAllAsRead(),
              child: const Text('Tandai semua dibaca'),
            ),
        ],
      ),
      body: SafeArea(
        child: notifAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            onRetry: () => ref.read(notifikasiNotifierProvider.notifier).refresh(),
          ),
          data: (items) {
            if (items.isEmpty) return const _EmptyState();
            return RefreshIndicator(
              onRefresh: () => ref.read(notifikasiNotifierProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.neutral100),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return _NotificationTile(
                    title: item.title,
                    message: item.message,
                    createdAt: item.createdAt,
                    isRead: item.isRead,
                    onTap: () => ref
                        .read(notifikasiNotifierProvider.notifier)
                        .markAsRead(item.id),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.onTap,
  });

  final String title;
  final String? message;
  final DateTime createdAt;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.white : AppColors.brand50,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 12),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : AppColors.brand500,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.neutral900,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      message!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.neutral400,
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

/// Format waktu relatif sederhana ("5 menit lalu", "3 hari lalu") tanpa
/// dependency tambahan (paket `intl` yang sudah ada di project ini tidak
/// punya util relative-time bawaan).
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_outlined,
                size: 48, color: AppColors.neutral300),
            const SizedBox(height: 12),
            const Text(
              'Belum ada notifikasi',
              style: TextStyle(
                color: AppColors.neutral500,
                fontWeight: FontWeight.w600,
              ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger600),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat notifikasi.',
              style: TextStyle(color: AppColors.neutral600),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
