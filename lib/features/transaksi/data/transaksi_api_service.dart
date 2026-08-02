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
  /// transaksi pending yang mau dilanjutkan pembayarannya. Belum dipakai
  /// UI (butuh WebView Midtrans, menyusul di step berikutnya) tapi data
  /// layer-nya disiapkan sekarang.
  Future<String> resumeTransaction(int id) async {
    final response = await _dio.post(ApiEndpoints.transactionResume(id));
    return response.data['snap_token'] as String;
  }
}

@Riverpod(keepAlive: true)
TransaksiApiService transaksiApiService(TransaksiApiServiceRef ref) {
  return TransaksiApiService(ref.watch(dioProvider));
}

