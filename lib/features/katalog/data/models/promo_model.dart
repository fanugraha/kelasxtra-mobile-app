// lib/features/katalog/data/models/promo_model.dart
//
// Model Promo -- dipakai di riwayat transaksi (transaction.promo) dan nanti
// checkout (promos/validate). Field & tipe cocok dengan `promos` table
// (dicocokkan ke migration, x-verified: source-code).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'promo_model.freezed.dart';
part 'promo_model.g.dart';

enum PromoDiscountType {
  @JsonValue('percentage')
  percentage,
  @JsonValue('fixed')
  fixed,
}

/// Laravel meng-cast kolom decimal sebagai STRING saat serialize ke JSON
/// (mis. "10000.00"), bukan number murni -- sama seperti price di Package.
double _decimalFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

@freezed
class PromoModel with _$PromoModel {
  const factory PromoModel({
    required int id,
    required String title,
    String? description,
    @JsonKey(name: 'discount_type') required PromoDiscountType discountType,
    @JsonKey(name: 'discount_value', fromJson: _decimalFromJson) required double discountValue,
    required String code,
  }) = _PromoModel;

  const PromoModel._();

  factory PromoModel.fromJson(Map<String, dynamic> json) => _$PromoModelFromJson(json);

  /// Label siap tampil, mis. "Diskon 10%" atau "Potongan Rp20.000".
  String get discountLabel => discountType == PromoDiscountType.percentage
      ? 'Diskon ${discountValue.toStringAsFixed(0)}%'
      : 'Potongan Rp${discountValue.toStringAsFixed(0)}';
}

/// POST /promos/validate -- x-verified: source-code. Response 200 kalau
/// kode valid untuk package_id/plan_id yang dikirim (belum bikin transaksi
/// apapun, murni pre-check untuk tombol "Terapkan"). 404 (kode tidak
/// ditemukan) & 422 (kedaluwarsa/kuota habis/new_user_only/dll) ditangani
/// sebagai ApiException biasa di repository -- pesannya sudah dari
/// backend, tidak perlu dipetakan ulang di client.
@freezed
class PromoValidationResult with _$PromoValidationResult {
  const factory PromoValidationResult({
    required PromoModel promo,
    @JsonKey(name: 'base_price', fromJson: _decimalFromJson) required double basePrice,
    @JsonKey(name: 'discount_amount', fromJson: _decimalFromJson) required double discountAmount,
    @JsonKey(name: 'final_amount', fromJson: _decimalFromJson) required double finalAmount,
  }) = _PromoValidationResult;

  factory PromoValidationResult.fromJson(Map<String, dynamic> json) =>
      _$PromoValidationResultFromJson(json);
}


