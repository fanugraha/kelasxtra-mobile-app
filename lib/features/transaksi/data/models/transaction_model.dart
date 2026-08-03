// lib/features/transaksi/data/models/transaction_model.dart
//
// Model Transaction -- field & tipe cocok dengan `transactions` table
// (dicocokkan ke migration + Transaction.php, x-verified: source-code).
// GET /transactions dan GET /transactions/{id} sama-sama eager-load
// package, plan, promo (lihat komentar TransactionController@index/show
// di backend) -- salah satu dari package/plan pasti null, tidak pernah
// keduanya terisi (transaksi paket biasa vs transaksi subscription).
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../katalog/data/models/package_model.dart';
import '../../../katalog/data/models/promo_model.dart';
import '../../../subscription/data/models/subscription_plan_model.dart';

part 'transaction_model.freezed.dart';
part 'transaction_model.g.dart';

/// Laravel meng-cast kolom decimal sebagai STRING saat serialize ke JSON,
/// sama seperti price di Package/Promo/SubscriptionPlan.
double _decimalFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

enum TransactionStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('success')
  success,
  @JsonValue('failed')
  failed,
  @JsonValue('expired')
  expired,
  @JsonValue('refunded')
  refunded,
}

@freezed
class TransactionModel with _$TransactionModel {
  const factory TransactionModel({
    required int id,
    // Salah satu dari package/plan null tergantung jenis transaksi --
    // lihat catatan di atas.
    PackageModel? package,
    SubscriptionPlanModel? plan,
    PromoModel? promo,
    @JsonKey(name: 'midtrans_order_id') String? midtransOrderId,
    @JsonKey(name: 'invoice_number') String? invoiceNumber,
    @JsonKey(fromJson: _decimalFromJson) required double amount,
    @JsonKey(name: 'discount_amount', fromJson: _decimalFromJson) @Default(0) double discountAmount,
    @JsonKey(name: 'payment_method') String? paymentMethod,
    required TransactionStatus status,
    @JsonKey(name: 'paid_at') String? paidAt,
    @JsonKey(name: 'expires_at') String? expiresAt,
    @JsonKey(name: 'created_at') String? createdAt,
    // Cuma terisi di response POST /transactions/checkout (backend
    // nge-attach lewat setAttribute, bukan kolom DB asli) -- dipakai buat
    // buka CheckoutWebViewScreen langsung setelah checkout sukses.
    @JsonKey(name: 'snap_token') String? snapToken,
  }) = _TransactionModel;

  const TransactionModel._();

  factory TransactionModel.fromJson(Map<String, dynamic> json) => _$TransactionModelFromJson(json);

  /// Nama item yang dibeli, siap tampil -- package ATAU plan, apa pun yang
  /// terisi.
  String get itemName => package?.name ?? plan?.name ?? 'Transaksi';

  /// Total yang dibayar setelah dipotong promo (amount di kolom DB memang
  /// sudah harga akhir, discount_amount cuma buat ditampilkan sebagai
  /// rincian potongan -- dicocokkan ke MidtransService::createTransaction).
  double get total => amount;

  bool get isPending => status == TransactionStatus.pending;
  bool get isSuccess => status == TransactionStatus.success;
}

