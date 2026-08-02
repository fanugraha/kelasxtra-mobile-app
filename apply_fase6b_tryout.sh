#!/usr/bin/env bash
# apply_fase6b_tryout.sh
#
# Fase 6b -- Wiring Tryout di tab Latihan.
#
# TEMUAN PENTING (diverifikasi ke source code backend & frontend web,
# bukan cuma dari OpenAPI spec): sistem ExamBatch/exam_batch_id di
# backend TIDAK PERNAH dipakai oleh flow start-exam siswa manapun --
# ExamController::forPackage() (endpoint /packages/{package}/exams,
# dipakai ExamListScreen) tidak pernah mengembalikan exam_batch_id, dan
# examService.startExam() di web frontend SELALU dipanggil dengan
# examBatchId=null (ExamDetail.jsx & MyClasses.jsx). Jadi Tryout di sini
# murni reuse Exam Engine yang sama seperti Latihan Fokus (tanpa batch),
# reuse cache enrollmentNotifierProvider yang sudah di-fetch untuk Paket
# Saya -- TIDAK ADA network call baru, TIDAK ADA model baru untuk batch.
#
# CARA PAKAI (di Mac, dari root repo kelasxtra-mobile-app):
#   1. git fetch && git reset --hard origin/main   (pastikan mulai dari state bersih)
#   2. Pindahkan file ini ke root repo, lalu:
#        chmod +x apply_fase6b_tryout.sh
#        ./apply_fase6b_tryout.sh
#      Script ini akan:
#        - membuat lib/features/katalog/presentation/screens/tryout_screen.dart
#        - mem-patch lib/core/router/app_router.dart (tambah route /tryout)
#        - mem-patch lib/features/katalog/presentation/screens/latihan_screen.dart
#          (kartu Tryout jadi tappable, Materi tetap "segera hadir")
#   3. flutter pub get
#   4. dart run build_runner build --delete-conflicting-outputs
#   5. flutter run -- cek tab Latihan, tap kartu Tryout, pastikan daftar
#      paket type=reguler yang sudah dibeli muncul, tap salah satu paket
#      aktif -> harus masuk ke ExamListScreen yang sudah ada.
#   6. git add -A && git commit -m "Fitur wiring Tryout (Fase 6b)"
#
# Aman dijalankan ulang (idempotent) -- script cek dulu apakah patch sudah
# ada sebelum menambahkan lagi.
set -euo pipefail

mkdir -p lib/features/katalog/presentation/screens

cat > "lib/features/katalog/presentation/screens/tryout_screen.dart" << 'DART_EOF'
// lib/features/katalog/presentation/screens/tryout_screen.dart
//
// Tryout = paket type `reguler` yang sudah dibeli siswa. TIDAK ada konsep
// exam_batch_id di flow ini -- sudah diverifikasi ke source backend
// (ExamController::forPackage() tidak pernah mengembalikan exam_batch_id)
// dan web frontend (examService.startExam() SELALU dipanggil dengan
// examBatchId=null, baik di ExamDetail.jsx maupun MyClasses.jsx). Model
// ExamBatch di backend ada tapi tidak tersambung ke flow start manapun --
// jadi Tryout di sini murni reuse Exam Engine yang sama seperti Latihan
// Fokus (tanpa batch), reuse cache enrollmentNotifierProvider yang sudah
// di-fetch untuk Paket Saya (tidak ada network call tambahan).
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
          final tryouts = enrollments.where((e) => e.package.type == PackageType.reguler).toList();
          if (tryouts.isEmpty) return const _EmptyState();

          final active = tryouts.where((e) => e.isActive).toList();
          final expired = tryouts.where((e) => !e.isActive).toList();

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

  @override
  Widget build(BuildContext context) {
    final isActive = enrollment.isActive;
    final pkg = enrollment.package;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isActive ? () => context.push('/paket/${pkg.id}/exams') : null,
      child: Opacity(
        opacity: isActive ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand50,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.emoji_events_outlined, color: AppColors.brand500, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pkg.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isActive ? 'Lihat daftar ujian' : 'Paket sudah kedaluwarsa',
                      style: TextStyle(
                        color: isActive ? AppColors.neutral500 : AppColors.danger600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive) const Icon(Icons.chevron_right, color: AppColors.neutral400),
            ],
          ),
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
            const Icon(Icons.emoji_events_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum punya paket Tryout',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Beli paket Try Out untuk mulai berlatih dengan simulasi ujian penuh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
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
              'Gagal memuat daftar Tryout',
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
DART_EOF

echo "tryout_screen.dart dibuat."

python3 << 'PY_EOF'
import re

# --- 1. app_router.dart: import + route ---
path = "lib/core/router/app_router.dart"
with open(path) as f:
    s = f.read()

anchor_import = "import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';"
if "tryout_screen.dart" not in s:
    s = s.replace(
        anchor_import,
        "import '../../features/katalog/presentation/screens/tryout_screen.dart';\n" + anchor_import,
        1,
    )

anchor_route = """      GoRoute(
        path: '/latihan-soal',
        builder: (_, __) => const LatihanKategoriScreen(),
      ),"""
new_route = """      GoRoute(
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
      ),
""" + anchor_route

if "path: '/tryout'" not in s:
    assert anchor_route in s, "anchor route latihan-soal tidak ditemukan di app_router.dart -- cek manual"
    s = s.replace(anchor_route, new_route, 1)

with open(path, "w") as f:
    f.write(s)
print("app_router.dart dipatch.")

# --- 2. latihan_screen.dart: TODO comment + Tryout card ---
path = "lib/features/katalog/presentation/screens/latihan_screen.dart"
with open(path) as f:
    s = f.read()

old_comment = """/// TODO: Try Out dan Materi masih menyusul. Latihan Soal per Topik sudah
/// jadi (lihat lib/features/latihan_fokus/), diarahkan dari sini."""
new_comment = """/// TODO: Materi masih menyusul. Latihan Soal per Topik (lib/features/latihan_fokus/)
/// dan Tryout (lib/features/katalog/presentation/screens/tryout_screen.dart)
/// sudah jadi, diarahkan dari sini."""
if old_comment in s:
    s = s.replace(old_comment, new_comment, 1)

old_block = """          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top_outlined, color: AppColors.neutral400, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tryout dan Materi segera hadir',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),"""

new_block = """          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/tryout'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.emoji_events_outlined, color: AppColors.gold600, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tryout',
                          style: TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Simulasi ujian penuh dari paket yang kamu punya',
                          style: TextStyle(color: AppColors.neutral500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.neutral400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top_outlined, color: AppColors.neutral400, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Materi segera hadir',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),"""

if "context.push('/tryout')" not in s:
    assert old_block in s, "anchor block Tryout-dan-Materi tidak ditemukan di latihan_screen.dart -- cek manual"
    s = s.replace(old_block, new_block, 1)

with open(path, "w") as f:
    f.write(s)
print("latihan_screen.dart dipatch.")
PY_EOF

echo "Selesai. Jangan lupa: flutter pub get && dart run build_runner build --delete-conflicting-outputs"
