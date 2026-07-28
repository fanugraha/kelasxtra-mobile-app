// lib/features/notifikasi/data/repositories/notifikasi_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../notifikasi_api_service.dart';
import '../models/notification_model.dart';

part 'notifikasi_repository.g.dart';

class NotifikasiRepository {
  NotifikasiRepository(this._api);

  final NotifikasiApiService _api;

  Future<List<NotificationModel>> getNotifications() async {
    try {
      return await _api.getNotifications();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _api.getUnreadCount();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _api.markAsRead(id);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.markAllAsRead();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

@riverpod
NotifikasiRepository notifikasiRepository(NotifikasiRepositoryRef ref) {
  return NotifikasiRepository(ref.watch(notifikasiApiServiceProvider));
}
