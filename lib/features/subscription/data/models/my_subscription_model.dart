// lib/features/subscription/data/models/my_subscription_model.dart
//
// Model buat GET /my-subscription. Field cocok dengan array yang dirakit
// manual di SubscriptionController@mySubscription (bukan hasil toJson
// Eloquent langsung, makanya field-nya lebih sedikit & flat -- x-verified:
// source-code).
import 'package:freezed_annotation/freezed_annotation.dart';

import 'subscription_plan_model.dart';

part 'my_subscription_model.freezed.dart';
part 'my_subscription_model.g.dart';

@freezed
class MySubscriptionModel with _$MySubscriptionModel {
  const factory MySubscriptionModel({
    required int id,
    required SubscriptionPlanModel plan,
    required String status,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'end_date') String? endDate,
    // Laravel pluck() balikin array of int biasa di JSON.
    @JsonKey(name: 'covered_program_ids') @Default([]) List<int> coveredProgramIds,
  }) = _MySubscriptionModel;

  const MySubscriptionModel._();

  factory MySubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$MySubscriptionModelFromJson(json);

  bool get isActive => status == 'active';
}

/// Wrapper response GET /my-subscription: `{ "subscription": null | {...} }`.
@freezed
class MySubscriptionResponse with _$MySubscriptionResponse {
  const factory MySubscriptionResponse({
    MySubscriptionModel? subscription,
  }) = _MySubscriptionResponse;

  factory MySubscriptionResponse.fromJson(Map<String, dynamic> json) =>
      _$MySubscriptionResponseFromJson(json);
}

