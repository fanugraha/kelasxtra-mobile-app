// lib/features/enrollment/presentation/screens/paket_saya_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/enrollment_provider.dart';

class PaketSayaScreen extends ConsumerWidget {
  const PaketSayaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(enrollmentNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Paket Saya'),
      ),
      body: enrollmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.read(enrollmentNotifierProvider.notifier).refresh(),
        ),
        data: (enrollments) {
          if (enrollments.isEmpty) return const _EmptyState();

          // is_active dari backend (hasil Enrollment::isActive(), bukan
          // kolom status mentah) -- lihat catatan di EnrollmentModel.
          final active = enrollments.where((e) => e.isActive).toList();
          final expired = enrollments.where((e) => !e.isActive).toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(enrollmentNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                if (active.isNotEmpty) ...[
                  const _SectionTitle(title: 'Aktif'),
                  const SizedBox(height: 12),
                  for (final e in active) ...[
                    _EnrollmentCard(enrollment: e),
                    const SizedBox(height: 12),
                  ],
                ],
                if (expired.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _SectionTitle(title: 'Kedaluwarsa'),
                  const SizedBox(height: 12),
                  for (final e in expired) ...[
                    _EnrollmentCard(enrollment: e),
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

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.enrollment});
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
                          child: const Icon(Icons.school_outlined, color: AppColors.neutral400),
                        ),
                      )
                    : Container(
                        color: AppColors.neutral100,
                        alignment: Alignment.center,
                        child: const Icon(Icons.school_outlined, color: AppColors.neutral400),
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
                      'Lihat Ujian',
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
            const Icon(Icons.inventory_2_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada paket yang dimiliki',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Beli paket try out atau kelas untuk mulai belajar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              // TODO: arahkan ke katalog paket begitu screen-nya dibangun.
              onPressed: () => context.pop(),
              child: const Text('Kembali'),
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
              'Gagal memuat paket kamu',
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
