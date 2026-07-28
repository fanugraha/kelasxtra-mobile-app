// lib/features/notifikasi/data/notifikasi_api_service.dart
//
// Panggilan HTTP mentah untuk fitur Notifikasi. Ikuti pola yang sama
// seperti BerandaApiService (raw Dio, bukan Retrofit) -- endpoint di sini
// sederhana (1 list + 2 aksi POST), tidak perlu codegen Retrofit.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/notification_model.dart';

part 'notifikasi_api_service.g.dart';

class NotifikasiApiService {
  NotifikasiApiService(this._dio);

  final Dio _dio;

  /// GET /notifications -- 30 notifikasi terbaru milik user yang login.
  Future<List<NotificationModel>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    final data = response.data as List<dynamic>;
    return data
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// GET /notifications/unread-count
  Future<int> getUnreadCount() async {
    final response = await _dio.get(ApiEndpoints.notificationsUnreadCount);
    final data = response.data as Map<String, dynamic>;
    return data['count'] as int? ?? 0;
  }

  /// POST /notifications/{id}/read
  Future<void> markAsRead(String id) async {
    await _dio.post(ApiEndpoints.notificationRead(id));
  }

  /// POST /notifications/read-all
  Future<void> markAllAsRead() async {
    await _dio.post(ApiEndpoints.notificationsReadAll);
  }
}

@Riverpod(keepAlive: true)
NotifikasiApiService notifikasiApiService(NotifikasiApiServiceRef ref) {
  return NotifikasiApiService(ref.watch(dioProvider));
}
