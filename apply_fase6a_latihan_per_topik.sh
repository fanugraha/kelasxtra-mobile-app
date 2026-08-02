#!/usr/bin/env bash
# apply_fase6a_latihan_per_topik.sh
# Fase 6.A -- Latihan Soal per Topik (3 layar: kategori -> topik -> roadmap)
# Jalankan dari root repo kelasxtra-mobile-app.
set -euo pipefail

mkdir -p lib/features/latihan_fokus/data/models
mkdir -p lib/features/latihan_fokus/presentation/providers
mkdir -p lib/features/latihan_fokus/presentation/screens

cat > "lib/features/latihan_fokus/data/models/latihan_fokus_model.dart" << 'DART_EOF'
// lib/features/latihan_fokus/data/models/latihan_fokus_model.dart
//
// Model untuk 3 layar Latihan Soal per Topik (tag "Latihan Fokus" di
// kelasxtra-openapi.yaml, semua endpoint x-verified: source-code):
//   Layar 1: GET /latihan-soal/categories               -> LatihanCategoryModel
//   Layar 2: GET /latihan-soal/categories/{id}/topics    -> LatihanTopicModel
//   Layar 3: GET /latihan-soal/topics/{id}/roadmap       -> LatihanRoadmapPartModel
import 'package:freezed_annotation/freezed_annotation.dart';

part 'latihan_fokus_model.freezed.dart';
part 'latihan_fokus_model.g.dart';

@freezed
class LatihanCategoryProgram with _$LatihanCategoryProgram {
  const factory LatihanCategoryProgram({
    int? id,
    String? name,
  }) = _LatihanCategoryProgram;

  factory LatihanCategoryProgram.fromJson(Map<String, dynamic> json) =>
      _$LatihanCategoryProgramFromJson(json);
}

/// Layar 1 -- kategori/mapel (mis. TWK, TIU, TKP) yang punya minimal 1
/// topik dengan part tersedia.
@freezed
class LatihanCategoryModel with _$LatihanCategoryModel {
  const factory LatihanCategoryModel({
    required int id,
    String? code,
    required String name,
    LatihanCategoryProgram? program,
  }) = _LatihanCategoryModel;

  factory LatihanCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanCategoryModelFromJson(json);
}

/// Layar 2 -- topik dalam 1 kategori + progress part yang sudah
/// diselesaikan.
@freezed
class LatihanTopicModel with _$LatihanTopicModel {
  const factory LatihanTopicModel({
    @JsonKey(name: 'topic_id') required int topicId,
    required String name,
    String? code,
    @JsonKey(name: 'total_parts') required int totalParts,
    @JsonKey(name: 'completed_parts') required int completedParts,
  }) = _LatihanTopicModel;

  factory LatihanTopicModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanTopicModelFromJson(json);
}

extension LatihanTopicProgressX on LatihanTopicModel {
  double get progressRatio => totalParts == 0 ? 0 : completedParts / totalParts;
  bool get isFullyCompleted => totalParts > 0 && completedParts >= totalParts;
}

enum LatihanRoadmapPartStatus {
  @JsonValue('completed')
  completed,
  @JsonValue('unlocked')
  unlocked,
  @JsonValue('locked_subscription')
  lockedSubscription,
  @JsonValue('locked_sequence')
  lockedSequence,
}

/// Layar 3 -- 1 part latihan dalam roadmap topik. [examId] dipakai
/// langsung sebagai path param ke `/exams/{examId}/summary` (reuse
/// ExamSummaryScreen dari Exam Engine -- part latihan soal berjalan lewat
/// alur mulai/lanjut yang sama seperti try-out, cuma tanpa exam_batch_id).
@freezed
class LatihanRoadmapPartModel with _$LatihanRoadmapPartModel {
  const factory LatihanRoadmapPartModel({
    @JsonKey(name: 'exam_id') required int examId,
    @JsonKey(name: 'part_number') int? partNumber,
    required String title,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    required LatihanRoadmapPartStatus status,
    @JsonKey(name: 'best_score') double? bestScore,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
  }) = _LatihanRoadmapPartModel;

  factory LatihanRoadmapPartModel.fromJson(Map<String, dynamic> json) =>
      _$LatihanRoadmapPartModelFromJson(json);
}

extension LatihanRoadmapPartX on LatihanRoadmapPartModel {
  bool get isLocked =>
      status == LatihanRoadmapPartStatus.lockedSubscription ||
      status == LatihanRoadmapPartStatus.lockedSequence;
}
DART_EOF

cat > "lib/features/latihan_fokus/data/latihan_fokus_api_service.dart" << 'DART_EOF'
// lib/features/latihan_fokus/data/latihan_fokus_api_service.dart
//
// Panggilan HTTP mentah untuk Latihan Soal per Topik. Ikuti pola
// EnrollmentApiService / NotifikasiApiService (raw Dio) -- 3 endpoint GET
// sederhana, tidak perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/latihan_fokus_model.dart';

part 'latihan_fokus_api_service.g.dart';

class LatihanFokusApiService {
  LatihanFokusApiService(this._dio);

  final Dio _dio;

  /// GET /latihan-soal/categories -- Layar 1.
  Future<List<LatihanCategoryModel>> getCategories() async {
    final response = await _dio.get(ApiEndpoints.latihanSoalCategories);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanCategoryModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /latihan-soal/categories/{taxonomy}/topics -- Layar 2.
  Future<List<LatihanTopicModel>> getTopics(int taxonomyId) async {
    final response = await _dio.get(ApiEndpoints.latihanSoalTopics(taxonomyId));
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanTopicModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /latihan-soal/topics/{topic}/roadmap -- Layar 3.
  Future<List<LatihanRoadmapPartModel>> getRoadmap(int topicId) async {
    final response = await _dio.get(ApiEndpoints.latihanSoalRoadmap(topicId));
    final data = response.data as List<dynamic>;
    return data
        .map((json) => LatihanRoadmapPartModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
LatihanFokusApiService latihanFokusApiService(LatihanFokusApiServiceRef ref) {
  return LatihanFokusApiService(ref.watch(dioProvider));
}
DART_EOF

cat > "lib/features/latihan_fokus/data/latihan_fokus_repository.dart" << 'DART_EOF'
// lib/features/latihan_fokus/data/latihan_fokus_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import 'latihan_fokus_api_service.dart';
import 'models/latihan_fokus_model.dart';

part 'latihan_fokus_repository.g.dart';

class LatihanFokusRepository {
  LatihanFokusRepository(this._api);

  final LatihanFokusApiService _api;

  Future<List<LatihanCategoryModel>> getCategories() async {
    try {
      return await _api.getCategories();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<LatihanTopicModel>> getTopics(int taxonomyId) async {
    try {
      return await _api.getTopics(taxonomyId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<LatihanRoadmapPartModel>> getRoadmap(int topicId) async {
    try {
      return await _api.getRoadmap(topicId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
LatihanFokusRepository latihanFokusRepository(LatihanFokusRepositoryRef ref) {
  return LatihanFokusRepository(ref.watch(latihanFokusApiServiceProvider));
}
DART_EOF

cat > "lib/features/latihan_fokus/presentation/providers/latihan_fokus_provider.dart" << 'DART_EOF'
// lib/features/latihan_fokus/presentation/providers/latihan_fokus_provider.dart
//
// Fetch tunggal, family per id -- pola yang sama seperti exam_provider.dart
// (Fase 2 Pre-Exam Flow): tidak perlu Notifier class untuk GET sederhana
// tanpa mutasi lokal.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/latihan_fokus_repository.dart';
import '../../data/models/latihan_fokus_model.dart';

export '../../data/models/latihan_fokus_model.dart';

part 'latihan_fokus_provider.g.dart';

/// GET /latihan-soal/categories -- Layar 1.
@riverpod
Future<List<LatihanCategoryModel>> latihanCategories(LatihanCategoriesRef ref) {
  return ref.watch(latihanFokusRepositoryProvider).getCategories();
}

/// GET /latihan-soal/categories/{taxonomy}/topics -- Layar 2.
@riverpod
Future<List<LatihanTopicModel>> latihanTopics(LatihanTopicsRef ref, int taxonomyId) {
  return ref.watch(latihanFokusRepositoryProvider).getTopics(taxonomyId);
}

/// GET /latihan-soal/topics/{topic}/roadmap -- Layar 3.
@riverpod
Future<List<LatihanRoadmapPartModel>> latihanRoadmap(LatihanRoadmapRef ref, int topicId) {
  return ref.watch(latihanFokusRepositoryProvider).getRoadmap(topicId);
}
DART_EOF

cat > "lib/features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart" << 'DART_EOF'
// lib/features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanKategoriScreen extends ConsumerWidget {
  const LatihanKategoriScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(latihanCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Latihan Soal per Topik'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat kategori',
          onRetry: () => ref.invalidate(latihanCategoriesProvider),
        ),
        data: (categories) {
          if (categories.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanCategoriesProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  'Pilih mapel, lalu susun roadmap belajarmu topik demi topik.',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final category in categories) ...[
                  _CategoryCard(category: category),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final LatihanCategoryModel category;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/latihan-soal/kategori/${category.id}',
        extra: category.name,
      ),
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
              child: const Icon(Icons.topic_outlined, color: AppColors.brand500, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (category.program?.name != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      category.program!.name!,
                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400),
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
            const Icon(Icons.topic_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada kategori latihan soal',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba lagi nanti setelah materi latihan tersedia.',
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
DART_EOF

cat > "lib/features/latihan_fokus/presentation/screens/latihan_topik_screen.dart" << 'DART_EOF'
// lib/features/latihan_fokus/presentation/screens/latihan_topik_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanTopikScreen extends ConsumerWidget {
  const LatihanTopikScreen({super.key, required this.taxonomyId, this.categoryName});

  final int taxonomyId;
  final String? categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(latihanTopicsProvider(taxonomyId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(categoryName ?? 'Topik'),
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat topik',
          onRetry: () => ref.invalidate(latihanTopicsProvider(taxonomyId)),
        ),
        data: (topics) {
          if (topics.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanTopicsProvider(taxonomyId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                for (final topic in topics) ...[
                  _TopicCard(topic: topic),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});
  final LatihanTopicModel topic;

  @override
  Widget build(BuildContext context) {
    final isDone = topic.isFullyCompleted;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/latihan-soal/topik/${topic.topicId}',
        extra: topic.name,
      ),
      child: Container(
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
                    topic.name,
                    style: const TextStyle(
                      color: AppColors.neutral900,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(
                        color: AppColors.success700,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: topic.progressRatio,
                minHeight: 6,
                backgroundColor: AppColors.neutral100,
                color: isDone ? AppColors.success600 : AppColors.brand500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${topic.completedParts}/${topic.totalParts} part selesai',
              style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.topic_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada topik di kategori ini',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
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
DART_EOF

cat > "lib/features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart" << 'DART_EOF'
// lib/features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/latihan_fokus_provider.dart';

class LatihanRoadmapScreen extends ConsumerWidget {
  const LatihanRoadmapScreen({super.key, required this.topicId, this.topicName});

  final int topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(latihanRoadmapProvider(topicId));

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: Text(topicName ?? 'Roadmap'),
      ),
      body: roadmapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat roadmap',
          onRetry: () => ref.invalidate(latihanRoadmapProvider(topicId)),
        ),
        data: (parts) {
          if (parts.isEmpty) return const _EmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(latihanRoadmapProvider(topicId)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                for (int i = 0; i < parts.length; i++) ...[
                  _RoadmapPartCard(part: parts[i], sequenceNumber: i + 1),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoadmapPartCard extends StatelessWidget {
  const _RoadmapPartCard({required this.part, required this.sequenceNumber});
  final LatihanRoadmapPartModel part;
  final int sequenceNumber;

  void _handleTap(BuildContext context) {
    switch (part.status) {
      case LatihanRoadmapPartStatus.completed:
      case LatihanRoadmapPartStatus.unlocked:
        context.push('/exams/${part.examId}/summary');
        break;
      case LatihanRoadmapPartStatus.lockedSequence:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selesaikan part sebelumnya dulu untuk membuka ini.')),
        );
        break;
      case LatihanRoadmapPartStatus.lockedSubscription:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Part ini butuh paket berlangganan aktif.')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = part.status == LatihanRoadmapPartStatus.completed;
    final isLocked = part.isLocked;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleTap(context),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success50
                    : (isLocked ? AppColors.neutral100 : AppColors.brand50),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, color: AppColors.success700, size: 18)
                  : isLocked
                      ? const Icon(Icons.lock_outline, color: AppColors.neutral400, size: 16)
                      : Text(
                          '$sequenceNumber',
                          style: const TextStyle(
                            color: AppColors.brand600,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.title,
                    style: TextStyle(
                      color: isLocked ? AppColors.neutral500 : AppColors.neutral900,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.neutral400, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        '${part.durationMinutes} menit',
                        style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                      ),
                      if (part.bestScore != null) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.emoji_events_outlined,
                            color: AppColors.neutral400, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          'Skor ${part.bestScore!.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                        ),
                      ],
                      if (part.isFreePreview) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.gold100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Pratinjau Gratis',
                            style: TextStyle(
                              color: AppColors.gold600,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock_outline : Icons.chevron_right,
              color: AppColors.neutral400,
              size: isLocked ? 16 : 22,
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Belum ada part latihan di topik ini',
              style: TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
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
DART_EOF

cat > "lib/core/router/app_router.dart" << 'DART_EOF'
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
import '../../features/exam_engine/presentation/screens/exam_attempt_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_list_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_review_screen.dart';
import '../../features/exam_engine/presentation/screens/exam_summary_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_kategori_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_roadmap_screen.dart';
import '../../features/latihan_fokus/presentation/screens/latihan_topik_screen.dart';
import '../../features/notifikasi/presentation/screens/notifikasi_screen.dart';
import '../../features/shell/presentation/screens/app_shell.dart';

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
        path: '/analisis-performa',
        builder: (_, __) => const AnalisisPerformaScreen(),
      ),
      GoRoute(
        path: '/paket-saya',
        builder: (_, __) => const PaketSayaScreen(),
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
DART_EOF

cat > "lib/features/katalog/presentation/screens/latihan_screen.dart" << 'DART_EOF'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// TODO: Try Out dan Materi masih menyusul. Latihan Soal per Topik sudah
/// jadi (lihat lib/features/latihan_fokus/), diarahkan dari sini.
class LatihanScreen extends StatelessWidget {
  const LatihanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        automaticallyImplyLeading: false,
        title: const Text('Latihan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/latihan-soal'),
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
                    child: const Icon(Icons.topic_outlined, color: AppColors.brand500, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latihan Soal per Topik',
                          style: TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Susun roadmap topik demi topik',
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
                    'Tryout dan Materi segera hadir',
                    style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

echo "Fase 6.A: Latihan Soal per Topik -- 9 file ditulis. Jalankan build_runner:"
echo "  dart run build_runner build --delete-conflicting-outputs"
