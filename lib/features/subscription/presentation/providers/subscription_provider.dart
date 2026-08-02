// lib/features/subscription/presentation/providers/subscription_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/my_subscription_model.dart';
import '../../data/models/subscription_plan_model.dart';
import '../../data/repositories/subscription_repository.dart';

export '../../data/models/my_subscription_model.dart';
export '../../data/models/subscription_plan_model.dart';

part 'subscription_provider.g.dart';

@riverpod
class SubscriptionPlansNotifier extends _$SubscriptionPlansNotifier {
  @override
  Future<List<SubscriptionPlanModel>> build() {
    return ref.watch(subscriptionRepositoryProvider).getPlans();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

@riverpod
class MySubscriptionNotifier extends _$MySubscriptionNotifier {
  @override
  Future<MySubscriptionModel?> build() {
    return ref.watch(subscriptionRepositoryProvider).getMySubscription();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

