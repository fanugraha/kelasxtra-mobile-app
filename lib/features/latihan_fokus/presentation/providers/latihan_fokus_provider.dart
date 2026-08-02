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
