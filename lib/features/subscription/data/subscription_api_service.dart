// lib/features/subscription/data/subscription_api_service.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/my_subscription_model.dart';
import 'models/subscription_plan_model.dart';

part 'subscription_api_service.g.dart';

class SubscriptionApiService {
  SubscriptionApiService(this._dio);

  final Dio _dio;

  /// GET /subscription-plans -- publik, daftar plan aktif dijual.
  Future<List<SubscriptionPlanModel>> getPlans() async {
    final response = await _dio.get(ApiEndpoints.subscriptionPlans);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => SubscriptionPlanModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /my-subscription -- subscription aktif milik user, null kalau
  /// belum pernah berlangganan.
  Future<MySubscriptionModel?> getMySubscription() async {
    final response = await _dio.get(ApiEndpoints.mySubscription);
    return MySubscriptionResponse.fromJson(response.data as Map<String, dynamic>).subscription;
  }
}

@Riverpod(keepAlive: true)
SubscriptionApiService subscriptionApiService(SubscriptionApiServiceRef ref) {
  return SubscriptionApiService(ref.watch(dioProvider));
}

