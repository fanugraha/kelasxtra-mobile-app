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

