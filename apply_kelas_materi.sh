mkdir -p lib/core/router lib/features/akun/presentation/screens lib/features/kelas_materi/data lib/features/kelas_materi/data/models lib/features/kelas_materi/data/repositories lib/features/kelas_materi/presentation/providers lib/features/kelas_materi/presentation/screens

cat > lib/features/kelas_materi/data/models/kelas_materi_model.dart << 'EOF_KELAS_MATERI_MODEL_DART'
// lib/features/kelas_materi/data/models/kelas_materi_model.dart
//
// x-verified STATUS PER ENDPOINT (lihat kelasxtra-openapi.yaml):
// - GET /classes            -> source-code (id, name, status, program_id,
//   is_accessible) -- ClassSummary di bawah AMAN dipakai apa adanya.
// - GET /materials/{id}     -> source-code (id, class_id, title, file_url,
//   type: pdf|video_link) -- MaterialItem di bawah AMAN dipakai apa adanya.
// - GET /classes/{id}       -> x-verified: inferred, DAN beda dari kasus
//   `question` di modul Tutor (yang MASIH dikasih parent object dengan tipe
//   jelas) -- di sini SELURUH body cuma "type: object" tanpa satupun
//   properti terdokumentasi. Summary endpoint cuma bilang isinya
//   "(+materials, +schedules, +tutor)".
//
// STRATEGI untuk ClassDetail (bagian yang inferred):
// 1. Field id/name/status/programId/isAccessible ditebak SAMA dengan
//    ClassSummary (masuk akal karena kemungkinan besar accessor Laravel-nya
//    ClassResource yang extends/reuse resource yang sama untuk list & show).
// 2. `materials` ditebak berupa list objek berbentuk sama seperti
//    MaterialItem (verified) -- karena kalaupun beda, field yang dipakai UI
//    (id, title, type) kemungkinan besar tetap ada dengan nama yang sama.
// 3. `schedules` BENAR-BENAR tidak ada petunjuk bentuknya sama sekali --
//    tidak ditebak jadi model spesifik. Disimpan sebagai List<dynamic> raw
//    dan screen merender apa adanya secara generik (key: value) supaya
//    tidak crash kalau bentuknya meleset, sekaligus tidak menyembunyikan
//    data dari user.
// 4. `tutor` ditebak {id, name} mengikuti pola TutorEssayAttemptUser yang
//    sudah dipakai di modul lain untuk representasi "person" ringkas.
// 5. SEMUA field kelas 2-4 nullable/default kosong -- kalau backend kirim
//    struktur berbeda, UI fallback ke "tidak tersedia" per-bagian, BUKAN
//    error/crash seluruh layar. Setelah dites dengan device asli dan log
//    Dio dicek, sanitasi ini WAJIB diperbaiki supaya cocok response asli
//    (sama seperti alur perbaikan questionText di modul Tutor kemarin).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'kelas_materi_model.freezed.dart';
part 'kelas_materi_model.g.dart';

/// GET /classes -- item list. x-verified: source-code.
@freezed
class ClassSummary with _$ClassSummary {
  const factory ClassSummary({
    required int id,
    required String name,
    required String status,
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'is_accessible') @Default(false) bool isAccessible,
  }) = _ClassSummary;

  factory ClassSummary.fromJson(Map<String, dynamic> json) => _$ClassSummaryFromJson(json);
}

/// GET /materials/{material} -- x-verified: source-code. Dipakai juga
/// sebagai tebakan bentuk item di ClassDetail.materials (lihat catatan di
/// atas file, poin 2).
@freezed
class MaterialItem with _$MaterialItem {
  const factory MaterialItem({
    required int id,
    @JsonKey(name: 'class_id') int? classId,
    required String title,
    @JsonKey(name: 'file_url') String? fileUrl,
    // enum: pdf | video_link -- disimpan String mentah (bukan enum Dart)
    // supaya nilai tak dikenal tidak bikin parsing gagal total, cuma
    // fallback ke tampilan generik di UI.
    String? type,
  }) = _MaterialItem;

  factory MaterialItem.fromJson(Map<String, dynamic> json) => _$MaterialItemFromJson(json);

  const MaterialItem._();

  bool get isPdf => type == 'pdf';
  bool get isVideoLink => type == 'video_link';
}

/// Representasi ringkas tutor pengampu kelas -- x-verified: UNVERIFIED,
/// tebakan pola {id, name} (lihat catatan poin 4).
@freezed
class ClassTutorRef with _$ClassTutorRef {
  const factory ClassTutorRef({
    int? id,
    String? name,
  }) = _ClassTutorRef;

  factory ClassTutorRef.fromJson(Map<String, dynamic> json) => _$ClassTutorRefFromJson(json);
}

/// GET /classes/{class} -- x-verified: UNVERIFIED (kecuali id/name/status/
/// programId/isAccessible yang dipinjam dari ClassSummary). Lihat catatan
/// panjang di atas file ini sebelum mengandalkan field apa pun di sini
/// untuk keputusan penting.
@freezed
class ClassDetail with _$ClassDetail {
  const factory ClassDetail({
    required int id,
    required String name,
    String? status,
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'is_accessible') @Default(true) bool isAccessible,
    // true kalau backend memang tidak kirim field ini sama sekali (bukan
    // array kosong) -- dipakai screen untuk membedakan "belum ada materi"
    // vs "field ini ternyata bukan `materials`, cek log Dio".
    @Default(<MaterialItem>[]) List<MaterialItem> materials,
    // Raw & tidak dimodelkan sama sekali -- lihat catatan poin 3.
    @Default(<dynamic>[]) List<dynamic> schedulesRaw,
    ClassTutorRef? tutor,
  }) = _ClassDetail;

  factory ClassDetail.fromJson(Map<String, dynamic> json) =>
      _$ClassDetailFromJson(sanitizeClassDetailJson(json));
}

/// Menyuntik ulang key jadi bentuk yang predictable SEBELUM fromJson
/// standar dipanggil -- pola yang sama dipakai di tutor_essay_model.dart
/// (sanitizeEssayQueueJson) supaya freezed toJson() tetap ter-generate
/// normal untuk class ini.
Map<String, dynamic> sanitizeClassDetailJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);

  final materialsRaw = sanitized['materials'];
  if (materialsRaw is! List) {
    sanitized['materials'] = <dynamic>[];
  }

  final schedulesRaw = sanitized['schedules'];
  sanitized['schedulesRaw'] = schedulesRaw is List ? schedulesRaw : <dynamic>[];

  return sanitized;
}

EOF_KELAS_MATERI_MODEL_DART

cat > lib/features/kelas_materi/data/kelas_materi_api_service.dart << 'EOF_KELAS_MATERI_API_SERVICE_DART'
// lib/features/kelas_materi/data/kelas_materi_api_service.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/kelas_materi_model.dart';

part 'kelas_materi_api_service.g.dart';

class KelasMateriApiService {
  KelasMateriApiService(this._dio);

  final Dio _dio;

  /// GET /classes -- x-verified: source-code.
  Future<List<ClassSummary>> getClasses() async {
    final response = await _dio.get(ApiEndpoints.classes);
    final data = response.data as List;
    return data.map((e) => ClassSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /classes/{class} -- x-verified: UNVERIFIED (lihat catatan di
  /// kelas_materi_model.dart). 403 kalau belum terdaftar aktif di kelas
  /// ini -- dibiarkan lempar DioException, ditangani di repository.
  Future<ClassDetail> getClassDetail(int classId) async {
    final response = await _dio.get(ApiEndpoints.classDetail(classId));
    return ClassDetail.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /materials/{material} -- x-verified: source-code. Dipakai kalau
  /// materi dibuka langsung dari luar konteks ClassDetail (mis. deep link),
  /// bukan dari list materials di ClassDetail (yang sudah datang dari
  /// sanitizeClassDetailJson).
  Future<MaterialItem> getMaterialDetail(int materialId) async {
    final response = await _dio.get(ApiEndpoints.materialDetail(materialId));
    return MaterialItem.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
KelasMateriApiService kelasMateriApiService(KelasMateriApiServiceRef ref) {
  return KelasMateriApiService(ref.watch(dioProvider));
}

EOF_KELAS_MATERI_API_SERVICE_DART

cat > lib/features/kelas_materi/data/repositories/kelas_materi_repository.dart << 'EOF_KELAS_MATERI_REPOSITORY_DART'
// lib/features/kelas_materi/data/repositories/kelas_materi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../kelas_materi_api_service.dart';
import '../models/kelas_materi_model.dart';

part 'kelas_materi_repository.g.dart';

class KelasMateriRepository {
  KelasMateriRepository(this._api);

  final KelasMateriApiService _api;

  Future<List<ClassSummary>> getClasses() async {
    try {
      return await _api.getClasses();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ClassDetail> getClassDetail(int classId) async {
    try {
      return await _api.getClassDetail(classId);
    } on DioException catch (e) {
      // Dilempar apa adanya (bukan di-null-kan) -- screen butuh
      // ApiException.isForbidden untuk beda-in pesan "belum terdaftar
      // aktif" vs error umum lain (lihat pola sama di TutorEssayQueue).
      throw ApiException.fromDioException(e);
    }
  }

  Future<MaterialItem> getMaterialDetail(int materialId) async {
    try {
      return await _api.getMaterialDetail(materialId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
KelasMateriRepository kelasMateriRepository(KelasMateriRepositoryRef ref) {
  return KelasMateriRepository(ref.watch(kelasMateriApiServiceProvider));
}

EOF_KELAS_MATERI_REPOSITORY_DART

cat > lib/features/kelas_materi/presentation/providers/kelas_materi_provider.dart << 'EOF_KELAS_MATERI_PROVIDER_DART'
// lib/features/kelas_materi/presentation/providers/kelas_materi_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/kelas_materi_model.dart';
import '../../data/repositories/kelas_materi_repository.dart';

export '../../data/models/kelas_materi_model.dart';

part 'kelas_materi_provider.g.dart';

@riverpod
class ClassListNotifier extends _$ClassListNotifier {
  @override
  Future<List<ClassSummary>> build() {
    return ref.watch(kelasMateriRepositoryProvider).getClasses();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// family per classId -- tiap layar detail kelas independen, tidak saling
/// invalidate satu sama lain saat pindah kelas.
@riverpod
class ClassDetailNotifier extends _$ClassDetailNotifier {
  @override
  Future<ClassDetail> build(int classId) {
    return ref.watch(kelasMateriRepositoryProvider).getClassDetail(classId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

EOF_KELAS_MATERI_PROVIDER_DART

cat > lib/features/kelas_materi/presentation/screens/kelas_list_screen.dart << 'EOF_KELAS_LIST_SCREEN_DART'
// lib/features/kelas_materi/presentation/screens/kelas_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/kelas_materi_provider.dart';

class KelasListScreen extends ConsumerWidget {
  const KelasListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classListNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Kelas'),
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat daftar kelas',
          onRetry: () => ref.read(classListNotifierProvider.notifier).refresh(),
        ),
        data: (classes) {
          if (classes.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () => ref.read(classListNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ClassCard(item: classes[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});
  final ClassSummary item;

  @override
  Widget build(BuildContext context) {
    final isLocked = !item.isAccessible;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // Tetap bisa dibuka walau is_accessible false -- biar user lihat
      // pesan 403 asli dari backend ("Belum terdaftar aktif di kelas
      // ini") daripada kelas ke-block total di sisi client berdasarkan
      // field yang belum tentu selalu akurat/up-to-date.
      onTap: () => context.push('/classes/${item.id}'),
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
                color: isLocked ? AppColors.neutral100 : AppColors.brand50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : Icons.school_outlined,
                color: isLocked ? AppColors.neutral400 : AppColors.brand600,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.status,
                    style: TextStyle(
                      color: isLocked ? AppColors.neutral400 : AppColors.success600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 20),
          ],
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
            const Icon(Icons.school_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada kelas',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kelas privat/group yang kamu ikuti akan muncul di sini.',
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

EOF_KELAS_LIST_SCREEN_DART

cat > lib/features/kelas_materi/presentation/screens/kelas_detail_screen.dart << 'EOF_KELAS_DETAIL_SCREEN_DART'
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

EOF_KELAS_DETAIL_SCREEN_DART

cat > lib/features/akun/presentation/screens/akun_screen.dart << 'EOF_AKUN_SCREEN_DART'
// lib/features/akun/presentation/screens/akun_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';

class AkunScreen extends ConsumerWidget {
  const AkunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

    // Fallback jaga-jaga -- AppShell (lewat redirect di app_router.dart)
    // seharusnya cuma bisa dicapai kalau authState = authenticated, tapi
    // ini menghindari null-check crash kalau state berubah tepat di frame
    // yang sama (mis. race dengan logout / token expired).
    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _ProfileHeader(user: user),
            const SizedBox(height: 20),
            if (user.emailVerifiedAt == null) ...[
              const _EmailNotVerifiedBanner(),
              const SizedBox(height: 20),
            ],
            const _SubscriptionCard(),
            const SizedBox(height: 20),
            _MenuSection(
              children: [
                _MenuTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Paket Saya',
                  onTap: () => context.push('/paket-saya'),
                ),
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Riwayat Transaksi',
                  onTap: () => context.push('/transaksi'),
                ),
                _MenuTile(
                  icon: Icons.person_outline,
                  label: 'Edit Profil',
                  onTap: () => context.push('/akun/edit-profil'),
                ),
                _MenuTile(
                  icon: Icons.lock_outline,
                  label: 'Ganti Password',
                  onTap: () => context.push('/akun/ganti-password'),
                ),
                _MenuTile(
                  icon: Icons.shield_outlined,
                  label: 'Privasi',
                  onTap: () => context.push('/privasi'),
                ),
                _MenuTile(
                  icon: Icons.school_outlined,
                  label: 'Kelas',
                  onTap: () => context.push('/classes'),
                ),
                // Cuma tutor/admin -- endpoint-nya sendiri role-gated
                // (403 kalau bukan), ini cuma menyembunyikan menu supaya
                // siswa biasa tidak lihat tombol yang pasti gagal.
                if (user.role == UserRole.tutor || user.role == UserRole.admin)
                  _MenuTile(
                    icon: Icons.rate_review_outlined,
                    label: 'Penilaian Essay',
                    onTap: () => context.push('/tutor/essay-queue'),
                  ),
                // TODO: menu "Ganti Password" di atas seharusnya disembunyikan
                // atau di-disable kalau user login via Google (googleId !=
                // null) -- akun Google tidak punya current_password untuk
                // divalidasi PUT /auth/password. Belum ada percabangan UI
                // untuk ini karena belum ada akun tes Google buat verifikasi
                // response error yang sebenarnya dari backend (422? pesan
                // apa?) -- cek dulu sebelum menambahkan penanganannya.
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.danger600),
                label: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger100),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Kamu perlu login lagi untuk mengakses akun ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.danger600)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.brand500,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.neutral900),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailNotVerifiedBanner extends ConsumerStatefulWidget {
  const _EmailNotVerifiedBanner();

  @override
  ConsumerState<_EmailNotVerifiedBanner> createState() => _EmailNotVerifiedBannerState();
}

class _EmailNotVerifiedBannerState extends ConsumerState<_EmailNotVerifiedBanner> {
  bool _isSending = false;
  bool _sent = false;

  Future<void> _resend(String email) async {
    setState(() => _isSending = true);
    final error = await ref.read(authNotifierProvider.notifier).resendVerificationEmail(email);
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _sent = error == null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (u) => u.email,
          orElse: () => '',
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold500.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.gold600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email belum diverifikasi',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral900, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _sent
                      ? 'Link verifikasi baru sudah dikirim ke $email.'
                      : 'Beberapa fitur mungkin terbatas sampai email diverifikasi.',
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 12),
                ),
                if (!_sent) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isSending ? null : () => _resend(email),
                    child: Text(
                      _isSending ? 'Mengirim...' : 'Kirim ulang email verifikasi',
                      style: const TextStyle(
                        color: AppColors.brand500,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sebelumnya kartu ini numpang data dari berandaNotifierProvider (satu-
/// satunya konsumen GET /my-subscription waktu itu). Sekarang lib/features/
/// subscription/ sudah ada provider sendiri (mySubscriptionNotifierProvider),
/// jadi dependency silang ke Beranda dilepas -- kartu ini juga jadi entry
/// point ke layar Langganan (daftar plan + detail).
class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(mySubscriptionNotifierProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/langganan'),
      child: subAsync.when(
        data: (subscription) {
          final isActive = subscription != null;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? AppColors.success50 : AppColors.neutral100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.verified_outlined : Icons.info_outline,
                  color: isActive ? AppColors.success600 : AppColors.neutral500,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive ? 'Langganan Aktif' : 'Belum Berlangganan',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.neutral900),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 2),
                        Text(
                          subscription.plan.name,
                          style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        // Gagal-lembut: kalau /my-subscription gagal load (mis. offline), kartu
        // status langganan cukup disembunyikan -- bukan alasan mengganggu
        // seluruh halaman Akun yang isinya hal lain juga (profil, menu, dst).
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, color: AppColors.neutral200),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.neutral600, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.neutral900)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 20),
      onTap: onTap,
    );
  }
}

EOF_AKUN_SCREEN_DART

cat > lib/core/router/app_router.dart << 'EOF_APP_ROUTER_DART'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/register_form_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/check_email_screen.dart';
import '../../features/akun/presentation/screens/edit_profil_screen.dart';
import '../../features/akun/presentation/screens/ganti_password_screen.dart';
import '../../features/beranda/presentation/screens/analisis_performa_screen.dart';
import '../../features/enrollment/presentation/screens/paket_saya_screen.dart';
import '../../features/katalog/data/models/package_model.dart';
import '../../features/katalog/presentation/screens/katalog_screen.dart';
import '../../features/katalog/presentation/screens/tryout_screen.dart';
import '../../features/kelas_materi/presentation/screens/kelas_detail_screen.dart';
import '../../features/kelas_materi/presentation/screens/kelas_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/privasi/presentation/screens/privasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';
import '../../features/subscription/presentation/screens/langganan_screen.dart';
import '../../features/transaksi/presentation/screens/checkout_webview_screen.dart';
import '../../features/transaksi/presentation/screens/riwayat_transaksi_screen.dart';
import '../../features/transaksi/presentation/screens/transaksi_detail_screen.dart';
import '../../features/tutor/presentation/screens/tutor_essay_queue_screen.dart';

part 'app_router.g.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter goRouter(GoRouterRef ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/register/form' ||
          loc == '/check-email' ||
          loc.startsWith('/forgot-password');

      return authState.when(
        unknown: () => isSplash ? null : '/splash',
        unauthenticated: () {
          if (isSplash) return '/login';
          if (isAuthRoute) return null;
          return '/login';
        },
        authenticated: (_) {
          if (isSplash || isAuthRoute) return '/home';
          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/register/form',
        builder: (_, __) => const RegisterFormScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return CheckEmailScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotifikasiScreen(),
      ),
      GoRoute(
        path: '/akun/edit-profil',
        builder: (_, __) => const EditProfilScreen(),
      ),
      GoRoute(
        path: '/akun/ganti-password',
        builder: (_, __) => const GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/privasi',
        builder: (_, __) => const PrivasiScreen(),
      ),
      GoRoute(
        path: '/tutor/essay-queue',
        builder: (_, __) => const TutorEssayQueueScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (_, __) => const KelasListScreen(),
      ),
      GoRoute(
        path: '/classes/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return KelasDetailScreen(classId: id);
        },
      ),
      GoRoute(
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
      ),
      GoRoute(
        path: '/transaksi',
        builder: (_, __) => const RiwayatTransaksiScreen(),
      ),
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TransaksiDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/langganan',
        builder: (_, __) => const LangganganScreen(),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final args = state.extra as CheckoutArgs;
          return CheckoutWebViewScreen(transactionId: args.transactionId, snapToken: args.snapToken);
        },
      ),
      GoRoute(
        path: '/tryout',
        builder: (_, __) => const TryoutScreen(),
      ),
      GoRoute(
        path: '/katalog',
        builder: (context, state) {
          final filter = state.extra as PackageType?;
          return KatalogScreen(initialFilter: filter);
        },
      ),
      GoRoute(
        path: '/latihan-soal',
        builder: (_, __) => const LatihanKategoriScreen(),
      ),
      GoRoute(
        path: '/latihan-soal/kategori/:taxonomyId',
        builder: (context, state) {
          final taxonomyId = int.parse(state.pathParameters['taxonomyId']!);
          final categoryName = state.extra as String?;
          return LatihanTopikScreen(taxonomyId: taxonomyId, categoryName: categoryName);
        },
      ),
      GoRoute(
        path: '/latihan-soal/topik/:topicId',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['topicId']!);
          final topicName = state.extra as String?;
          return LatihanRoadmapScreen(topicId: topicId, topicName: topicName);
        },
      ),
      GoRoute(
        path: '/paket/:packageId/exams',
        builder: (context, state) {
          final packageId = int.parse(state.pathParameters['packageId']!);
          return ExamListScreen(packageId: packageId);
        },
      ),
      GoRoute(
        path: '/exams/:examId/summary',
        builder: (context, state) {
          final examId = int.parse(state.pathParameters['examId']!);
          return ExamSummaryScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamAttemptScreen(attemptId: attemptId);
        },
      ),
      GoRoute(
        path: '/exam-attempts/:attemptId/review',
        builder: (context, state) {
          final attemptId = int.parse(state.pathParameters['attemptId']!);
          return ExamReviewScreen(attemptId: attemptId);
        },
      ),
    ],
  );
}


EOF_APP_ROUTER_DART

echo 'Modul Kelas Materi (daftar kelas, detail kelas, materi) selesai dibangun.'