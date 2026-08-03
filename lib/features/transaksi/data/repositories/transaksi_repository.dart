// lib/features/transaksi/data/repositories/transaksi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/transaction_model.dart';
import '../transaksi_api_service.dart';

part 'transaksi_repository.g.dart';

class TransaksiRepository {
  TransaksiRepository(this._api);

  final TransaksiApiService _api;

  Future<List<TransactionModel>> getTransactions() async {
    try {
      return await _api.getTransactions();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> getTransactionDetail(int id) async {
    try {
      return await _api.getTransactionDetail(id);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<String> resumeTransaction(int id) async {
    try {
      return await _api.resumeTransaction(id);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> checkoutPackage(int packageId, {String? promoCode}) async {
    try {
      return await _api.checkoutPackage(packageId, promoCode: promoCode);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TransactionModel> checkoutPlan(int planId, {String? promoCode, List<int>? programIds}) async {
    try {
      return await _api.checkoutPlan(planId, promoCode: promoCode, programIds: programIds);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
TransaksiRepository transaksiRepository(TransaksiRepositoryRef ref) {
  return TransaksiRepository(ref.watch(transaksiApiServiceProvider));
}

