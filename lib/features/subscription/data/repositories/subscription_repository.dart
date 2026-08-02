// lib/features/subscription/data/repositories/subscription_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/my_subscription_model.dart';
import '../models/subscription_plan_model.dart';
import '../subscription_api_service.dart';

part 'subscription_repository.g.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._api);

  final SubscriptionApiService _api;

  Future<List<SubscriptionPlanModel>> getPlans() async {
    try {
      return await _api.getPlans();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MySubscriptionModel?> getMySubscription() async {
    try {
      return await _api.getMySubscription();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
SubscriptionRepository subscriptionRepository(SubscriptionRepositoryRef ref) {
  return SubscriptionRepository(ref.watch(subscriptionApiServiceProvider));
}

