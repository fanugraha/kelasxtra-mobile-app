// lib/features/subscription/data/models/subscription_plan_model.dart
//
// Model SubscriptionPlan -- field & tipe cocok dengan `subscription_plans`
// table (dicocokkan ke migration + SubscriptionPlan.php, x-verified:
// source-code). Dipakai sekarang oleh modul transaksi (transaction.plan),
// nanti oleh modul subscription penuh (GET /subscription-plans,
// GET /my-subscription) begitu dibangun.
import 'package:freezed_annotation/freezed_annotation.dart';

// PENTING: JANGAN pakai `show PackageProgram` di sini. Freezed men-generate
// mixin `$PackageProgramCopyWith` di package_model.freezed.dart sebagai
// bagian dari library package_model.dart (lewat `part`) -- `show` cuma
// meloloskan nama yang disebut, jadi CopyWith generated-nya ikut
// ke-hide dan compile subscription_plan_model.freezed.dart gagal
// ("Type '$PackageProgramCopyWith' not found").
import '../../../katalog/data/models/package_model.dart';

part 'subscription_plan_model.freezed.dart';
part 'subscription_plan_model.g.dart';

/// Laravel meng-cast kolom decimal sebagai STRING saat serialize ke JSON
/// (mis. "150000.00"), bukan number murni -- sama seperti price di Package.
double _priceFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

@freezed
class SubscriptionPlanModel with _$SubscriptionPlanModel {
  const factory SubscriptionPlanModel({
    required int id,
    required String name,
    String? tagline,
    String? description,
    // Nullable, bukan @Default([]) -- kolom JSON di DB bisa null kalau
    // admin belum isi bullet-point benefit-nya.
    List<String>? features,
    @JsonKey(name: 'duration_days') required int durationDays,
    // null = plan fix ke 1 program ([program] terisi). Terisi = plan
    // multi-select, user pilih N program saat checkout (lihat
    // SubscriptionPlan::isFixedProgram() di backend).
    @JsonKey(name: 'program_slot_count') int? programSlotCount,
    @JsonKey(name: 'program_id') int? programId,
    PackageProgram? program,
    @JsonKey(fromJson: _priceFromJson) required double price,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
  }) = _SubscriptionPlanModel;

  const SubscriptionPlanModel._();

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanModelFromJson(json);

  bool get isFixedProgram => programSlotCount == null;
}

