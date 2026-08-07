mkdir -p lib/features/tutor/data/models lib/features/tutor/data/repositories lib/features/tutor/presentation/providers lib/features/tutor/presentation/screens

cat > lib/features/tutor/data/models/tutor_essay_model.dart << 'EOF_MODEL'
// lib/features/tutor/data/models/tutor_essay_model.dart
//
// Model untuk antrian penilaian essay (role-gated: tutor/admin).
// GET /tutor/essay-queue -- x-verified: source-code untuk field top-level
// (id, needs_manual_grading, essay_answer, attempt.user.{id,name}), TAPI
// field `question` di spec CUMA "type: object" tanpa properti terdokumentasi
// sama sekali -- beda dari endpoint lain di project ini yang semuanya
// full-typed. Lihat sanitizeEssayQueueJson di bawah untuk cara field itu
// ditangani.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tutor_essay_model.freezed.dart';
part 'tutor_essay_model.g.dart';

@freezed
class TutorEssayAttemptUser with _$TutorEssayAttemptUser {
  const factory TutorEssayAttemptUser({
    required int id,
    required String name,
  }) = _TutorEssayAttemptUser;

  factory TutorEssayAttemptUser.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayAttemptUserFromJson(json);
}

@freezed
class TutorEssayAttemptRef with _$TutorEssayAttemptRef {
  const factory TutorEssayAttemptRef({
    TutorEssayAttemptUser? user,
  }) = _TutorEssayAttemptRef;

  factory TutorEssayAttemptRef.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayAttemptRefFromJson(json);
}

@freezed
class TutorEssayQueueItem with _$TutorEssayQueueItem {
  const factory TutorEssayQueueItem({
    // Ini id JAWABAN (answer), bukan id soal -- dipakai langsung sebagai
    // path param {answer} di POST /tutor/essay-answers/{answer}/grade.
    required int id,
    @JsonKey(name: 'needs_manual_grading') @Default(true) bool needsManualGrading,
    @JsonKey(name: 'essay_answer') String? essayAnswer,
    // x-verified: UNVERIFIED. Disuntik sanitizeEssayQueueJson dari
    // question.question_text -- BUKAN key asli response (spec tidak kasih
    // skema apa pun untuk `question`). Tebakan paling masuk akal (tutor
    // pasti butuh baca soal buat menilai), belum pernah dicocokkan ke
    // response asli. Null kalau backend ternyata tidak kirim field itu --
    // UI HARUS fallback ke pesan generik, jangan asumsikan selalu ada.
    @JsonKey(name: '_question_text') String? questionText,
    TutorEssayAttemptRef? attempt,
  }) = _TutorEssayQueueItem;

  factory TutorEssayQueueItem.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayQueueItemFromJson(json);
}

@freezed
class TutorEssayQueueResponse with _$TutorEssayQueueResponse {
  const factory TutorEssayQueueResponse({
    // Laravel paginator -- cuma `data` yang didokumentasikan spec (bukan
    // links/meta), jadi MVP ini cuma render halaman pertama (20 item),
    // belum ada "muat lebih banyak". Field paginasi lain sengaja tidak
    // dimodelkan supaya tidak berasumsi ada, bukan dihilangkan sengaja.
    @Default(<TutorEssayQueueItem>[]) List<TutorEssayQueueItem> data,
  }) = _TutorEssayQueueResponse;

  factory TutorEssayQueueResponse.fromJson(Map<String, dynamic> json) =>
      _$TutorEssayQueueResponseFromJson(json);
}

/// Suntik `_question_text` dari question.question_text SEBELUM fromJson
/// standar dipanggil -- BUKAN override TutorEssayQueueItem.fromJson
/// langsung, karena itu bikin freezed skip generate toJson() juga untuk
/// class itu (pelajaran dari kasus PerformanceSection, lihat catatan di
/// beranda_models.dart). Pola sanitasi eksternal ini sudah 2x terbukti
/// aman dipakai di project ini.
Map<String, dynamic> sanitizeEssayQueueJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);
  final dataRaw = sanitized['data'];
  if (dataRaw is List) {
    sanitized['data'] = dataRaw.map((item) {
      if (item is! Map) return item;
      final itemMap = Map<String, dynamic>.from(item);
      final questionRaw = itemMap['question'];
      if (questionRaw is Map && questionRaw['question_text'] is String) {
        itemMap['_question_text'] = questionRaw['question_text'];
      }
      return itemMap;
    }).toList();
  }
  return sanitized;
}
EOF_MODEL

cat > lib/features/tutor/data/tutor_api_service.dart << 'EOF_API'
// lib/features/tutor/data/tutor_api_service.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/tutor_essay_model.dart';

part 'tutor_api_service.g.dart';

class TutorApiService {
  TutorApiService(this._dio);

  final Dio _dio;

  /// GET /tutor/essay-queue -- role-gated (tutor/admin), 403 kalau bukan.
  Future<TutorEssayQueueResponse> getEssayQueue() async {
    final response = await _dio.get(ApiEndpoints.tutorEssayQueue);
    return TutorEssayQueueResponse.fromJson(
      sanitizeEssayQueueJson(response.data as Map<String, dynamic>),
    );
  }

  /// POST /tutor/essay-answers/{answer}/grade -- response-nya
  /// {message, data: ExamAttempt (skor sudah dihitung ulang)}, tapi UI
  /// tutor tidak butuh detail attempt itu (bukan konteks pengerjaan
  /// soal), jadi sengaja tidak diparse -- cukup tahu request sukses
  /// (tidak throw) atau tidak.
  Future<void> gradeEssay({required int answerId, required bool isCorrect}) async {
    await _dio.post(
      ApiEndpoints.tutorGradeEssay(answerId),
      data: {'is_correct': isCorrect},
    );
  }
}

@Riverpod(keepAlive: true)
TutorApiService tutorApiService(TutorApiServiceRef ref) {
  return TutorApiService(ref.watch(dioProvider));
}
EOF_API

cat > lib/features/tutor/data/repositories/tutor_repository.dart << 'EOF_REPO'
// lib/features/tutor/data/repositories/tutor_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/tutor_essay_model.dart';
import '../tutor_api_service.dart';

part 'tutor_repository.g.dart';

class TutorRepository {
  TutorRepository(this._api);

  final TutorApiService _api;

  Future<List<TutorEssayQueueItem>> getEssayQueue() async {
    try {
      final response = await _api.getEssayQueue();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Return null kalau sukses, pesan error kalau gagal (422: jawaban ini
  /// bukan essay/sudah dinilai -- lihat spec).
  Future<String?> gradeEssay({required int answerId, required bool isCorrect}) async {
    try {
      await _api.gradeEssay(answerId: answerId, isCorrect: isCorrect);
      return null;
    } on DioException catch (e) {
      return ApiException.fromDioException(e).message;
    }
  }
}

@riverpod
TutorRepository tutorRepository(TutorRepositoryRef ref) {
  return TutorRepository(ref.watch(tutorApiServiceProvider));
}
EOF_REPO

cat > lib/features/tutor/presentation/providers/tutor_provider.dart << 'EOF_PROV'
// lib/features/tutor/presentation/providers/tutor_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/tutor_essay_model.dart';
import '../../data/repositories/tutor_repository.dart';

export '../../data/models/tutor_essay_model.dart';

part 'tutor_provider.g.dart';

@riverpod
class TutorEssayQueueNotifier extends _$TutorEssayQueueNotifier {
  @override
  Future<List<TutorEssayQueueItem>> build() {
    return ref.watch(tutorRepositoryProvider).getEssayQueue();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Return null kalau sukses (item langsung dihapus dari list lokal,
  /// optimistic -- tidak nunggu refetch penuh), pesan error kalau gagal
  /// (item TETAP di list, biar tutor bisa coba lagi).
  Future<String?> gradeEssay({required int answerId, required bool isCorrect}) async {
    final error = await ref.read(tutorRepositoryProvider).gradeEssay(
          answerId: answerId,
          isCorrect: isCorrect,
        );
    if (error != null) return error;

    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((item) => item.id != answerId).toList());
    }
    return null;
  }
}
EOF_PROV

cat > lib/features/tutor/presentation/screens/tutor_essay_queue_screen.dart << 'EOF_SCREEN'
// lib/features/tutor/presentation/screens/tutor_essay_queue_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/tutor_provider.dart';

class TutorEssayQueueScreen extends ConsumerWidget {
  const TutorEssayQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(tutorEssayQueueNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Penilaian Essay'),
      ),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) {
          final isForbidden = error is ApiException && error.isForbidden;
          return _ErrorState(
            message: isForbidden
                ? 'Kamu tidak punya akses ke halaman ini.'
                : (error is ApiException ? error.message : 'Gagal memuat antrian penilaian'),
            onRetry: isForbidden
                ? null
                : () => ref.read(tutorEssayQueueNotifierProvider.notifier).refresh(),
          );
        },
        data: (items) {
          if (items.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () => ref.read(tutorEssayQueueNotifierProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _EssayCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _EssayCard extends ConsumerStatefulWidget {
  const _EssayCard({required this.item});
  final TutorEssayQueueItem item;

  @override
  ConsumerState<_EssayCard> createState() => _EssayCardState();
}

class _EssayCardState extends ConsumerState<_EssayCard> {
  bool _isSubmitting = false;

  Future<void> _handleGrade(bool isCorrect) async {
    setState(() => _isSubmitting = true);
    final error = await ref
        .read(tutorEssayQueueNotifierProvider.notifier)
        .gradeEssay(answerId: widget.item.id, isCorrect: isCorrect);

    if (!mounted) return;
    if (error != null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    // Kalau sukses, item ini sudah dihapus dari list oleh notifier
    // (optimistic) -- widget ini otomatis ke-unmount lewat rebuild
    // ListView.separated, tidak perlu setState _isSubmitting=false lagi.
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final studentName = item.attempt?.user?.name ?? 'Siswa';

    return Container(
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
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.brand50,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.brand600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  studentName,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.questionText ?? '(soal tidak bisa ditampilkan)',
            style: TextStyle(
              color: item.questionText != null ? AppColors.neutral700 : AppColors.neutral400,
              fontSize: 13,
              fontStyle: item.questionText != null ? FontStyle.normal : FontStyle.italic,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.essayAnswer?.trim().isNotEmpty == true
                  ? item.essayAnswer!
                  : '(jawaban kosong)',
              style: const TextStyle(color: AppColors.neutral900, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleGrade(false),
                  icon: const Icon(Icons.close, size: 16, color: AppColors.danger600),
                  label: const Text('Salah', style: TextStyle(color: AppColors.danger600)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger100)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleGrade(true),
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Benar'),
                ),
              ),
            ],
          ),
        ],
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
            const Icon(Icons.task_alt, color: AppColors.success600, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Tidak ada essay yang perlu dinilai',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Semua jawaban essay sudah dinilai. Kerja bagus!',
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
  final VoidCallback? onRetry;

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
EOF_SCREEN

cat > lib/features/akun/presentation/screens/akun_screen.dart << 'EOF_AKUN'
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
EOF_AKUN

cat > lib/core/router/app_router.dart << 'EOF_ROUTER'
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

EOF_ROUTER

echo 'Modul Tutor (antrian & penilaian essay) selesai dibangun.'
