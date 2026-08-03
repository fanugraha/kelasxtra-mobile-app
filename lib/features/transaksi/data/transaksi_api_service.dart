// lib/features/transaksi/data/transaksi_api_service.dart
//
// Panggilan HTTP mentah untuk Transaksi. Ikuti pola EnrollmentApiService
// (raw Dio) -- cuma 3 endpoint, tidak perlu Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/transaction_model.dart';

part 'transaksi_api_service.g.dart';

class TransaksiApiService {
  TransaksiApiService(this._dio);

  final Dio _dio;

  /// GET /transactions -- riwayat transaksi user, sudah eager-load
  /// package/plan/promo dari backend.
  Future<List<TransactionModel>> getTransactions() async {
    final response = await _dio.get(ApiEndpoints.transactions);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => TransactionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /transactions/{id}
  Future<TransactionModel> getTransactionDetail(int id) async {
    final response = await _dio.get(ApiEndpoints.transactionDetail(id));
    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /transactions/{id}/resume -- ambil snap_token baru untuk
  /// transaksi pending yang mau dilanjutkan pembayarannya.
  Future<String> resumeTransaction(int id) async {
    final response = await _dio.post(ApiEndpoints.transactionResume(id));
    return response.data['snap_token'] as String;
  }

  /// POST /transactions/checkout -- beli paket (package_id). Backend
  /// otomatis resume kalau ternyata sudah ada transaksi pending untuk
  /// paket yang sama (lihat komentar TransactionController@checkout),
  /// jadi aman dipanggil berkali-kali tanpa bikin baris dobel.
  Future<TransactionModel> checkoutPackage(int packageId, {String? promoCode}) async {
    final response = await _dio.post(ApiEndpoints.checkout, data: {
      'package_id': packageId,
      if (promoCode != null) 'promo_code': promoCode,
    });
    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /transactions/checkout -- beli plan langganan (plan_id).
  /// [programIds] cuma wajib diisi kalau plan-nya multi-select
  /// (program_slot_count terisi) -- untuk plan fix-ke-1-program, backend
  /// otomatis pakai plan.program_id, tidak perlu dikirim.
  Future<TransactionModel> checkoutPlan(int planId, {String? promoCode, List<int>? programIds}) async {
    final response = await _dio.post(ApiEndpoints.checkout, data: {
      'plan_id': planId,
      if (promoCode != null) 'promo_code': promoCode,
      if (programIds != null) 'program_ids': programIds,
    });
    return TransactionModel.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
TransaksiApiService transaksiApiService(TransaksiApiServiceRef ref) {
  return TransaksiApiService(ref.watch(dioProvider));
}

