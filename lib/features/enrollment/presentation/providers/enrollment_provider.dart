// lib/features/enrollment/presentation/providers/enrollment_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/enrollment_repository.dart';
import '../../data/models/enrollment_model.dart';

export '../../data/models/enrollment_model.dart';

part 'enrollment_provider.g.dart';

@riverpod
class EnrollmentNotifier extends _$EnrollmentNotifier {
  @override
  Future<List<EnrollmentModel>> build() {
    return ref.watch(enrollmentRepositoryProvider).getMyPackages();
  }

  /// Dipanggil dari pull-to-refresh di layar Paket Saya.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
