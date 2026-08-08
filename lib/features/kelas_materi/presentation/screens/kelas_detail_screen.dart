// lib/features/kelas_materi/presentation/screens/kelas_detail_screen.dart
//
// PENTING: ClassDetail (materials/schedules/tutor) x-verified: UNVERIFIED
// kecuali field materials (ditebak reuse bentuk MaterialItem). Kalau
// setelah dites section "Jadwal" kosong padahal seharusnya ada data, atau
// section "Materi" tidak muncul padahal kelasnya ada materinya, itu tanda
// sanitizeClassDetailJson perlu diperbaiki -- kirim log Dio GET
// /classes/{id} biar saya cocokkan field-nya.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/kelas_materi_provider.dart';

class KelasDetailScreen extends ConsumerWidget {
  const KelasDetailScreen({super.key, required this.classId});
  final int classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(classDetailNotifierProvider(classId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(detailAsync.valueOrNull?.name ?? 'Detail Kelas'),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final isForbidden = error is ApiException && error.isForbidden;
          return _ErrorState(
            message: isForbidden
                ? 'Kamu belum terdaftar aktif di kelas ini.'
                : (error is ApiException ? error.message : 'Gagal memuat detail kelas'),
            onRetry: isForbidden
                ? null
                : () => ref.read(classDetailNotifierProvider(classId).notifier).refresh(),
          );
        },
        data: (detail) => RefreshIndicator(
          onRefresh: () => ref.read(classDetailNotifierProvider(classId).notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (detail.status != null) _StatusBadge(status: detail.status!),
              if (detail.tutor?.name != null) ...[
                const SizedBox(height: 16),
                _TutorCard(tutor: detail.tutor!),
              ],
              const SizedBox(height: 24),
              const _SectionTitle('Materi'),
              const SizedBox(height: 10),
              if (detail.materials.isEmpty)
                const _SectionEmptyHint('Belum ada materi di kelas ini.')
              else
                ...detail.materials.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MaterialTile(material: m),
                  ),
                ),
              const SizedBox(height: 24),
              const _SectionTitle('Jadwal'),
              const SizedBox(height: 10),
              if (detail.schedulesRaw.isEmpty)
                const _SectionEmptyHint('Belum ada jadwal untuk kelas ini.')
              else
                ...detail.schedulesRaw.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ScheduleRawTile(raw: s),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(color: AppColors.success700, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TutorCard extends StatelessWidget {
  const _TutorCard({required this.tutor});
  final ClassTutorRef tutor;

  @override
  Widget build(BuildContext context) {
    final name = tutor.name ?? 'Tutor';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand50,
            child: Text(
              initial,
              style: const TextStyle(color: AppColors.brand600, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tutor Pengampu',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  name,
                  style: const TextStyle(color: AppColors.neutral900, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.neutral900, fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.neutral500, fontSize: 13));
  }
}

class _MaterialTile extends StatefulWidget {
  const _MaterialTile({required this.material});
  final MaterialItem material;

  @override
  State<_MaterialTile> createState() => _MaterialTileState();
}

class _MaterialTileState extends State<_MaterialTile> {
  bool _isOpening = false;

  Future<void> _open() async {
    final url = widget.material.fileUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materi ini belum punya file/link.')),
      );
      return;
    }

    setState(() => _isOpening = true);
    try {
      // launchUrl (bukan WebView) -- PDF & video_link (kemungkinan besar
      // YouTube) sama-sama lebih baik ditangani app eksternal (viewer PDF
      // asli / app YouTube) daripada di-embed WebView, dan project ini
      // belum punya dependency PDF viewer. Sudah ada url_launcher sebagai
      // dependency (dipakai juga di checkout web fallback).
      final uri = Uri.parse(url);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka materi ini.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka materi ini.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final isPdf = material.isPdf;
    final icon = isPdf
        ? Icons.picture_as_pdf_outlined
        : material.isVideoLink
            ? Icons.play_circle_outline
            : Icons.insert_drive_file_outlined;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _isOpening ? null : _open,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brand600, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                material.title,
                style: const TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (_isOpening)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.open_in_new, color: AppColors.neutral400, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Bentuk `schedules` sepenuhnya tidak diketahui (lihat catatan di
/// kelas_materi_model.dart) -- tile ini merender pasangan key: value
/// generik dari Map mentah supaya data tetap kelihatan ke user (bukan
/// hilang total) sambil menunggu bentuk asli dikonfirmasi dari log Dio.
class _ScheduleRawTile extends StatelessWidget {
  const _ScheduleRawTile({required this.raw});
  final dynamic raw;

  @override
  Widget build(BuildContext context) {
    if (raw is! Map) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Text('$raw', style: const TextStyle(color: AppColors.neutral700, fontSize: 13)),
      );
    }

    final map = Map<String, dynamic>.from(raw as Map);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_outlined, color: AppColors.brand600, size: 18),
              SizedBox(width: 8),
              Text('Jadwal', style: TextStyle(color: AppColors.neutral500, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in map.entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${entry.key}: ${entry.value}',
                style: const TextStyle(color: AppColors.neutral900, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      ),
    );
  }
}

