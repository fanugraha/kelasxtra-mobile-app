import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// Bentuk item GET /notifications sesuai schema di kelasxtra-openapi.yaml.
/// `data` SENGAJA disimpan sebagai Map mentah (bukan diparse ke class
/// spesifik) karena backend bilang payload-nya "bebas sesuai jenis
/// notifikasi" (leaderboard reward, dll) -- belum ada daftar tipe resmi.
/// Getter [title]/[message] di bawah cuma best-effort baca key umum;
/// kalau backend kirim struktur lain, fallback ke teks generik supaya
/// list tetap tampil, tidak crash.
@freezed
class NotificationModel with _$NotificationModel {
  const factory NotificationModel({
    required String id,
    required Map<String, dynamic> data,
    @JsonKey(name: 'read_at') DateTime? readAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _NotificationModel;

  const NotificationModel._();

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  bool get isRead => readAt != null;

  /// Best-effort -- isi `data` belum ada daftar tipe resmi dari backend,
  /// jadi kalau nanti ketemu bentuk baru, tambahkan key yang dicoba di
  /// sini (jangan asumsikan semua notifikasi punya bentuk yang sama).
  String get title {
    final t = data['title'];
    if (t is String && t.isNotEmpty) return t;
    return 'Notifikasi';
  }

  String? get message {
    final m = data['message'] ?? data['body'] ?? data['text'];
    return m is String ? m : null;
  }
}
