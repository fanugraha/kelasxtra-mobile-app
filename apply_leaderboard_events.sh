#!/bin/bash
set -e

mkdir -p lib/features/leaderboard/data/models

cat > lib/core/utils/formatters.dart << 'EOF_7C57260EAE'
// lib/core/utils/formatters.dart
//
// Formatter angka/tanggal kecil yang dipakai lintas modul (transaksi,
// subscription, katalog, beranda) -- sebelumnya terduplikasi persis sama
// di beberapa tempat (transaksi_format.dart, subscription_format.dart,
// _formatRupiah privat di beranda_screen.dart). Dikonsolidasi ke sini
// supaya modul baru (katalog, dst) tidak nambah copy lagi.
//
// Sengaja hand-rolled, bukan intl's DateFormat/NumberFormat.currency --
// itu butuh initializeDateFormatting('id_ID') dulu di main.dart yang belum
// ada di project ini, dan formatnya cukup sederhana untuk ditulis manual.

const _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// 150000.0 -> "Rp150.000"
String formatRupiah(double amount) {
  final rounded = amount.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
  }

  return 'Rp$buffer';
}

/// "2026-08-02T10:15:00.000000Z" -> "2 Agu 2026, 10:15"
String formatTanggal(String? isoString) {
  if (isoString == null) return '-';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '-';
  final local = date.toLocal();
  final jam = local.hour.toString().padLeft(2, '0');
  final menit = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}, $jam:$menit';
}

/// "2026-08-02" atau "2026-08-02T00:00:00.000000Z" -> "2 Agu 2026"
String formatTanggalSingkat(String? dateString) {
  if (dateString == null) return '-';
  final date = DateTime.tryParse(dateString);
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}';
}

/// Format waktu relatif sederhana ("5 menit lalu", "3 hari lalu") tanpa
/// dependency tambahan (paket `intl` yang sudah ada di project ini tidak
/// punya util relative-time bawaan). Dipindah dari notifikasi_screen.dart
/// (privat di sana) supaya bisa dipakai modul lain (leaderboard events)
/// tanpa duplikasi.
String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return '${dt.day}/${dt.month}/${dt.year}';
}

/// 30 -> "30 hari", 365 -> "1 tahun", 90 -> "3 bulan" (pembulatan kasar,
/// cukup buat label kartu plan/paket).
String formatDurasi(int days) {
  if (days % 365 == 0 && days >= 365) {
    final years = days ~/ 365;
    return years == 1 ? '1 tahun' : '$years tahun';
  }
  if (days % 30 == 0 && days >= 30) {
    final months = days ~/ 30;
    return months == 1 ? '1 bulan' : '$months bulan';
  }
  return '$days hari';
}
EOF_7C57260EAE

cat > lib/features/leaderboard/data/leaderboard_api_service.dart << 'EOF_D8B2C4B095'
// lib/features/leaderboard/data/leaderboard_api_service.dart
//
// Panggilan HTTP mentah untuk Leaderboard Latihan Soal (mingguan). Ikuti
// pola LatihanFokusApiService (raw Dio) -- 3 endpoint GET sederhana, tidak
// perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/leaderboard_event_model.dart';
import 'models/leaderboard_model.dart';

part 'leaderboard_api_service.g.dart';

class LeaderboardApiService {
  LeaderboardApiService(this._dio);

  final Dio _dio;

  /// GET /exams/leaderboard/ranked
  Future<LeaderboardRankedResponse> getRankedExams() async {
    final response = await _dio.get(ApiEndpoints.examsLeaderboardRanked);
    return LeaderboardRankedResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exams/{exam}/leaderboard
  Future<LeaderboardIndexResponse> getLeaderboard(int examId) async {
    final response = await _dio.get(ApiEndpoints.examLeaderboard(examId));
    return LeaderboardIndexResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /exams/{exam}/leaderboard/me
  Future<LeaderboardMyPosition> getMyPosition(int examId) async {
    final response = await _dio.get(ApiEndpoints.examLeaderboardMe(examId));
    return LeaderboardMyPosition.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /leaderboard-events/me -- default backend: 10 menit terakhir kalau
  /// [since] tidak diisi. Sengaja tidak expose paging/limit -- backend sudah
  /// batasi maxItems 5.
  Future<LeaderboardMyEventsResponse> getMyEvents({DateTime? since}) async {
    final response = await _dio.get(
      ApiEndpoints.leaderboardEventsMe,
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return LeaderboardMyEventsResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /leaderboard-events/feed -- default backend: 2 menit terakhir kalau
  /// [since] tidak diisi (jendela lebih pendek dari /me karena ini feed
  /// publik semua siswa, bukan cuma milik user).
  Future<LeaderboardFeedResponse> getFeedEvents({DateTime? since}) async {
    final response = await _dio.get(
      ApiEndpoints.leaderboardEventsFeed,
      queryParameters: since != null ? {'since': since.toUtc().toIso8601String()} : null,
    );
    return LeaderboardFeedResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
LeaderboardApiService leaderboardApiService(LeaderboardApiServiceRef ref) {
  return LeaderboardApiService(ref.watch(dioProvider));
}
EOF_D8B2C4B095

cat > lib/features/leaderboard/data/leaderboard_repository.dart << 'EOF_E7E01B3B01'
// lib/features/leaderboard/data/leaderboard_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'leaderboard_api_service.dart';
import 'models/leaderboard_event_model.dart';
import 'models/leaderboard_model.dart';

part 'leaderboard_repository.g.dart';

class LeaderboardRepository {
  LeaderboardRepository(this._api);

  final LeaderboardApiService _api;

  Future<LeaderboardRankedResponse> getRankedExams() async {
    try {
      return await _api.getRankedExams();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<LeaderboardIndexResponse> getLeaderboard(int examId) async {
    try {
      return await _api.getLeaderboard(examId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Return null kalau user belum punya ranking di exam+periode ini (404
  /// dari server) -- itu KONDISI NORMAL (belum pernah attempt exam ini
  /// minggu ini), bukan error, jadi TIDAK dilempar sebagai ApiException.
  /// Error selain 404 tetap dilempar seperti biasa.
  Future<LeaderboardMyPosition?> getMyPosition(int examId) async {
    try {
      return await _api.getMyPosition(examId);
    } on DioException catch (e) {
      final apiException = ApiException.fromDioException(e);
      if (apiException.isNotFound) return null;
      throw apiException;
    }
  }

  /// GET /leaderboard-events/me -- notifikasi rank berubah milik user
  /// sendiri. Tidak ada kondisi 404 khusus di endpoint ini (selalu 200,
  /// `events` bisa kosong), jadi tidak perlu penanganan beda seperti
  /// [getMyPosition].
  Future<LeaderboardMyEventsResponse> getMyEvents({DateTime? since}) async {
    try {
      return await _api.getMyEvents(since: since);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET /leaderboard-events/feed -- event rank berubah milik siswa lain.
  Future<LeaderboardFeedResponse> getFeedEvents({DateTime? since}) async {
    try {
      return await _api.getFeedEvents(since: since);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
LeaderboardRepository leaderboardRepository(LeaderboardRepositoryRef ref) {
  return LeaderboardRepository(ref.watch(leaderboardApiServiceProvider));
}
EOF_E7E01B3B01

cat > lib/features/leaderboard/data/models/leaderboard_event_model.dart << 'EOF_E99ABE690C'
// lib/features/leaderboard/data/models/leaderboard_event_model.dart
//
// Model untuk Leaderboard Events -- x-verified: source-code, dibaca dari
// LeaderboardEventController.php + PracticeLeaderboardService.php.
// Event ini di-generate dari jalur yang SAMA dengan Leaderboard Latihan
// Soal mingguan (lihat leaderboard_model.dart) tiap kali
// PracticeLeaderboardService::generateForExam() jalan -- BUKAN dari
// /exam-batches/* (yang menurut audit Fase 6b tidak tersambung ke attempt
// manapun), jadi aman dipakai.
//
// Backend catat event HANYA kalau rank user menembus milestone (Top
// 50/10/3) atau membaik >= threshold posisi -- bukan tiap kali leaderboard
// re-generate. Wajar kalau kedua endpoint ini sering balik `events: []`.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_event_model.freezed.dart';
part 'leaderboard_event_model.g.dart';

/// GET /leaderboard-events/me -- 1 event rank-change milik user sendiri.
/// `oldRank` null berarti ini pertama kali dia masuk ranking periode ini
/// (dan langsung menembus milestone).
@freezed
class LeaderboardMyEvent with _$LeaderboardMyEvent {
  const factory LeaderboardMyEvent({
    required int id,
    @JsonKey(name: 'exam_title') required String examTitle,
    @JsonKey(name: 'old_rank') int? oldRank,
    @JsonKey(name: 'new_rank') required int newRank,
    @JsonKey(name: 'is_milestone') required bool isMilestone,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _LeaderboardMyEvent;

  factory LeaderboardMyEvent.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardMyEventFromJson(json);
}

@freezed
class LeaderboardMyEventsResponse with _$LeaderboardMyEventsResponse {
  const factory LeaderboardMyEventsResponse({
    @Default(<LeaderboardMyEvent>[]) List<LeaderboardMyEvent> events,
  }) = _LeaderboardMyEventsResponse;

  factory LeaderboardMyEventsResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardMyEventsResponseFromJson(json);
}

/// GET /leaderboard-events/feed -- 1 event rank-change milik siswa lain.
/// `displayName` sudah dipotong jadi "Nama I." oleh backend (nama lengkap
/// tidak pernah dikirim) -- jangan diproses ulang di client.
@freezed
class LeaderboardFeedEvent with _$LeaderboardFeedEvent {
  const factory LeaderboardFeedEvent({
    required int id,
    @JsonKey(name: 'display_name') required String displayName,
    @JsonKey(name: 'new_rank') required int newRank,
    @JsonKey(name: 'is_milestone') required bool isMilestone,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _LeaderboardFeedEvent;

  factory LeaderboardFeedEvent.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFeedEventFromJson(json);
}

@freezed
class LeaderboardFeedResponse with _$LeaderboardFeedResponse {
  const factory LeaderboardFeedResponse({
    @Default(<LeaderboardFeedEvent>[]) List<LeaderboardFeedEvent> events,
  }) = _LeaderboardFeedResponse;

  factory LeaderboardFeedResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFeedResponseFromJson(json);
}
EOF_E99ABE690C

cat > lib/features/leaderboard/presentation/providers/leaderboard_provider.dart << 'EOF_D940D18C7B'
// lib/features/leaderboard/presentation/providers/leaderboard_provider.dart
//
// Fetch sederhana + 1 state lokal untuk exam yang lagi dipilih di dropdown.
// Pola sama seperti latihan_fokus_provider.dart (GET tanpa mutasi lokal ->
// tidak perlu Notifier class), kecuali [selectedLeaderboardExamId] yang
// murni UI state (dropdown), bukan hasil fetch server.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/leaderboard_repository.dart';
import '../../data/models/leaderboard_event_model.dart';
import '../../data/models/leaderboard_model.dart';

export '../../data/models/leaderboard_event_model.dart';
export '../../data/models/leaderboard_model.dart';

part 'leaderboard_provider.g.dart';

/// GET /exams/leaderboard/ranked -- daftar exam yang punya leaderboard
/// aktif periode berjalan, dipakai isi dropdown pemilihan exam.
@riverpod
Future<LeaderboardRankedResponse> leaderboardRankedExams(LeaderboardRankedExamsRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getRankedExams();
}

/// Exam yang lagi dipilih di dropdown -- null berarti belum ada pilihan
/// eksplisit dari user, screen yang default-kan ke exam pertama dari
/// [leaderboardRankedExamsProvider] begitu data itu sampai (lihat
/// leaderboard_screen.dart, bukan di sini, supaya provider ini tidak perlu
/// tahu soal provider lain).
@riverpod
class SelectedLeaderboardExamId extends _$SelectedLeaderboardExamId {
  @override
  int? build() => null;

  void select(int examId) => state = examId;
}

/// GET /exams/{exam}/leaderboard -- Top 50 periode berjalan untuk exam
/// yang dipilih.
@riverpod
Future<LeaderboardIndexResponse> leaderboardEntries(LeaderboardEntriesRef ref, int examId) {
  return ref.watch(leaderboardRepositoryProvider).getLeaderboard(examId);
}

/// GET /exams/{exam}/leaderboard/me -- posisi user login. Null kalau user
/// belum punya ranking di exam+periode ini (lihat catatan repository).
@riverpod
Future<LeaderboardMyPosition?> leaderboardMyPosition(LeaderboardMyPositionRef ref, int examId) {
  return ref.watch(leaderboardRepositoryProvider).getMyPosition(examId);
}

/// GET /leaderboard-events/me -- notifikasi rank berubah milik user
/// sendiri (default backend: 10 menit terakhir). Fetch sekali per buka
/// layar Peringkat + pull-to-refresh, TIDAK auto-polling di background --
/// pola sama seperti provider lain di modul ini, supaya tidak menambah
/// mekanisme baru (timer/websocket) yang belum ada presisinya di project.
@riverpod
Future<LeaderboardMyEventsResponse> leaderboardMyEvents(LeaderboardMyEventsRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getMyEvents();
}

/// GET /leaderboard-events/feed -- event rank berubah milik siswa lain
/// (default backend: 2 menit terakhir).
@riverpod
Future<LeaderboardFeedResponse> leaderboardFeed(LeaderboardFeedRef ref) {
  return ref.watch(leaderboardRepositoryProvider).getFeedEvents();
}
EOF_D940D18C7B

cat > lib/features/leaderboard/presentation/screens/leaderboard_screen.dart << 'EOF_9BA8CD82B3'
// lib/features/leaderboard/presentation/screens/leaderboard_screen.dart
//
// Tab "Peringkat" -- Leaderboard Latihan Soal mingguan. Dropdown pilih
// exam (yang punya leaderboard aktif periode berjalan) -> kartu posisi
// user sendiri -> Top 50. TIDAK ada logika exam_batch_id sama sekali,
// lihat catatan di data/models/leaderboard_model.dart kenapa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/leaderboard_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankedAsync = ref.watch(leaderboardRankedExamsProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Peringkat'),
      ),
      body: rankedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat leaderboard',
          onRetry: () => ref.invalidate(leaderboardRankedExamsProvider),
        ),
        data: (ranked) {
          if (ranked.data.isEmpty) return const _EmptyRankedState();
          return _LeaderboardBody(rankedExams: ranked.data);
        },
      ),
    );
  }
}

class _LeaderboardBody extends ConsumerWidget {
  const _LeaderboardBody({required this.rankedExams});
  final List<LeaderboardRankedExam> rankedExams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Default ke exam pertama kalau user belum pernah pilih secara
    // eksplisit -- dihitung inline (bukan disuntik ke provider saat
    // build) supaya build() tetap murni, tidak trigger rebuild tambahan.
    final selectedId =
        ref.watch(selectedLeaderboardExamIdProvider) ?? rankedExams.first.id;
    final currentUserId = ref.watch(authNotifierProvider).maybeWhen(
          authenticated: (user) => user.id,
          orElse: () => null,
        );

    final entriesAsync = ref.watch(leaderboardEntriesProvider(selectedId));
    final myPositionAsync = ref.watch(leaderboardMyPositionProvider(selectedId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardEntriesProvider(selectedId));
        ref.invalidate(leaderboardMyPositionProvider(selectedId));
        ref.invalidate(leaderboardMyEventsProvider);
        ref.invalidate(leaderboardFeedProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _LeaderboardEventsSection(),
          _ExamDropdown(
            rankedExams: rankedExams,
            selectedId: selectedId,
            onChanged: (id) =>
                ref.read(selectedLeaderboardExamIdProvider.notifier).select(id),
          ),
          const SizedBox(height: 16),
          myPositionAsync.when(
            loading: () => const _MyPositionSkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (myPosition) => myPosition == null
                ? const _NoRankingYetCard()
                : _MyPositionCard(myPosition: myPosition),
          ),
          const SizedBox(height: 20),
          const Text(
            'Top 50 Minggu Ini',
            style: TextStyle(
              color: AppColors.neutral900,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorState(
              message: error is ApiException ? error.message : 'Gagal memuat ranking',
              onRetry: () => ref.invalidate(leaderboardEntriesProvider(selectedId)),
            ),
            data: (index) {
              if (index.data.isEmpty) return const _EmptyEntriesState();
              return Column(
                children: [
                  for (final entry in index.data)
                    _EntryRow(entry: entry, isMe: entry.userId == currentUserId),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExamDropdown extends StatelessWidget {
  const _ExamDropdown({
    required this.rankedExams,
    required this.selectedId,
    required this.onChanged,
  });

  final List<LeaderboardRankedExam> rankedExams;
  final int selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedId,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.neutral500),
          items: [
            for (final exam in rankedExams)
              DropdownMenuItem(
                value: exam.id,
                child: Text(
                  '${exam.title} · ${exam.participantsCount} peserta',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

class _MyPositionCard extends StatelessWidget {
  const _MyPositionCard({required this.myPosition});
  final LeaderboardMyPosition myPosition;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand500,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Posisi Kamu',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${myPosition.ranking}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'dari ${myPosition.totalPeserta} peserta',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Skor terbaik: ${myPosition.skorTerbaik}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (myPosition.rewardType != null) ...[
            const SizedBox(height: 10),
            _RewardBadge(rewardType: myPosition.rewardType!, onDark: true),
          ],
        ],
      ),
    );
  }
}

class _NoRankingYetCard extends StatelessWidget {
  const _NoRankingYetCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.neutral400, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Kamu belum punya ranking di exam ini minggu ini. Kerjakan latihan soalnya buat mulai bersaing!',
              style: TextStyle(color: AppColors.neutral600, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyPositionSkeleton extends StatelessWidget {
  const _MyPositionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isMe});
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.brand50 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? AppColors.brand200 : AppColors.neutral200),
      ),
      child: Row(
        children: [
          _RankBadge(ranking: entry.ranking),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.user?.name ?? 'Peserta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (entry.rewardType != null) ...[
                  const SizedBox(height: 4),
                  _RewardBadge(rewardType: entry.rewardType!, onDark: false),
                ],
              ],
            ),
          ),
          Text(
            '${entry.skorTerbaik}',
            style: const TextStyle(
              color: AppColors.neutral900,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.ranking});
  final int ranking;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (ranking) {
      1 => (AppColors.gold600, AppColors.gold100),
      2 => (AppColors.neutral600, AppColors.neutral100),
      3 => (AppColors.brand600, AppColors.brand100),
      _ => (AppColors.neutral500, AppColors.neutral50),
    };
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '$ranking',
        style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.rewardType, required this.onDark});
  final LeaderboardRewardType rewardType;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final label = switch (rewardType) {
      LeaderboardRewardType.voucherGold => 'Voucher Emas',
      LeaderboardRewardType.voucherSilver => 'Voucher Perak',
      LeaderboardRewardType.voucherBronze => 'Voucher Perunggu',
      LeaderboardRewardType.badgeOnly => 'Lencana Top Peserta',
    };
    final bg = onDark ? Colors.white.withOpacity(0.18) : AppColors.gold100;
    final fg = onDark ? Colors.white : AppColors.gold600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyRankedState extends StatelessWidget {
  const _EmptyRankedState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.leaderboard_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada leaderboard aktif minggu ini',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kerjakan latihan soal supaya leaderboard mingguan mulai terbentuk.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEntriesState extends StatelessWidget {
  const _EmptyEntriesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Belum ada peserta di ranking exam ini.',
          style: TextStyle(color: AppColors.neutral500, fontSize: 13),
        ),
      ),
    );
  }
}

/// "Aktivitas Peringkat" -- gabungan notifikasi rank pribadi
/// ([leaderboardMyEventsProvider], default window 10 menit terakhir di
/// backend) dan feed publik rank siswa lain ([leaderboardFeedProvider],
/// window 2 menit). TIDAK terikat exam yang dipilih di dropdown --
/// event lintas semua exam yang punya leaderboard aktif.
///
/// Section ini sengaja TIDAK ditampilkan sama sekali kalau kedua-duanya
/// kosong (bukan tampilkan "empty state") -- backend hanya catat event
/// saat rank menembus milestone/naik signifikan, jadi kosong adalah
/// kondisi NORMAL sehari-hari, bukan sesuatu yang perlu dijelaskan ke
/// user tiap buka layar ini.
class _LeaderboardEventsSection extends ConsumerWidget {
  const _LeaderboardEventsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myEventsAsync = ref.watch(leaderboardMyEventsProvider);
    final feedAsync = ref.watch(leaderboardFeedProvider);

    final myEvents = myEventsAsync.valueOrNull?.events ?? const [];
    final feedEvents = feedAsync.valueOrNull?.events ?? const [];

    if (myEvents.isEmpty && feedEvents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in myEvents) ...[
            _MyEventCard(event: event),
            const SizedBox(height: 8),
          ],
          if (feedEvents.isNotEmpty) _FeedEventList(events: feedEvents),
        ],
      ),
    );
  }
}

/// Kartu notifikasi rank pribadi berubah -- pakai warna gold kalau
/// menembus milestone (Top 50/10/3), brand kalau cuma naik signifikan
/// biasa, supaya milestone terasa lebih "istimewa".
class _MyEventCard extends StatelessWidget {
  const _MyEventCard({required this.event});
  final LeaderboardMyEvent event;

  @override
  Widget build(BuildContext context) {
    final accent = event.isMilestone ? AppColors.gold600 : AppColors.brand600;
    final bg = event.isMilestone ? AppColors.gold100 : AppColors.brand50;
    final text = event.oldRank == null
        ? 'Kamu masuk ranking di posisi #${event.newRank} untuk "${event.examTitle}"'
        : 'Rank kamu naik dari #${event.oldRank} ke #${event.newRank} di "${event.examTitle}"';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            event.isMilestone ? Icons.emoji_events_outlined : Icons.trending_up,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(color: accent, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  formatRelativeTime(event.createdAt.toLocal()),
                  style: const TextStyle(color: AppColors.neutral500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feed publik anonim rank siswa lain naik -- daftar ringkas, bukan kartu
/// besar per item, supaya tidak mendominasi layar dibanding leaderboard
/// utamanya sendiri.
class _FeedEventList extends StatelessWidget {
  const _FeedEventList({required this.events});
  final List<LeaderboardFeedEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final event in events) _FeedEventRow(event: event),
        ],
      ),
    );
  }
}

class _FeedEventRow extends StatelessWidget {
  const _FeedEventRow({required this.event});
  final LeaderboardFeedEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            event.isMilestone ? Icons.emoji_events_outlined : Icons.trending_up,
            color: event.isMilestone ? AppColors.gold600 : AppColors.neutral400,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5),
                children: [
                  TextSpan(
                    text: event.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.neutral900),
                  ),
                  TextSpan(text: ' naik ke rank #${event.newRank}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatRelativeTime(event.createdAt.toLocal()),
            style: const TextStyle(color: AppColors.neutral400, fontSize: 10.5),
          ),
        ],
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
EOF_9BA8CD82B3

cat > lib/features/notifikasi/presentation/screens/notifikasi_screen.dart << 'EOF_906A65F974'
// lib/features/notifikasi/presentation/screens/notifikasi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
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
                    formatRelativeTime(createdAt),
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
EOF_906A65F974

echo "Selesai. Jalankan: dart run build_runner build --delete-conflicting-outputs"
