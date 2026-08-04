// lib/features/katalog/presentation/providers/katalog_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/package_model.dart';
import '../../data/repositories/katalog_repository.dart';

export '../../data/models/package_model.dart';

part 'katalog_provider.g.dart';

@riverpod
class KatalogNotifier extends _$KatalogNotifier {
  @override
  Future<List<PackageModel>> build() {
    return ref.watch(katalogRepositoryProvider).getPackages();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
