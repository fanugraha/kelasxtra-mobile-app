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
