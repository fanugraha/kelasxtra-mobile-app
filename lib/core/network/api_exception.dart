import 'package:dio/dio.dart';

/// Representasi error API yang seragam, dipetakan dari response Laravel:
/// { "message": "...", "errors": { "field": ["..."] } }
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors,
    this.raw,
  });

  /// Dibuat dari DioException supaya semua repository menangani error
  /// dengan cara yang sama, tanpa parsing ulang di tiap tempat.
  factory ApiException.fromDioException(DioException e) {
    final response = e.response;

    if (response == null) {
      // Tidak ada koneksi / timeout
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(message: 'Koneksi timeout. Periksa jaringan Anda.');
        case DioExceptionType.connectionError:
          return ApiException(message: 'Tidak ada koneksi internet.');
        default:
          return ApiException(message: 'Terjadi kesalahan tak terduga.');
      }
    }

    final data = response.data;
    String message = 'Terjadi kesalahan. Coba lagi.';
    Map<String, List<String>>? fieldErrors;

    if (data is Map<String, dynamic>) {
      message = (data['message'] as String?) ?? message;
      final errors = data['errors'];
      if (errors is Map<String, dynamic>) {
        fieldErrors = errors.map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
        );
      }
    }

    return ApiException(
      message: message,
      statusCode: response.statusCode,
      fieldErrors: fieldErrors,
      raw: data is Map<String, dynamic> ? data : null,
    );
  }

  final String message;
  final int? statusCode;

  /// Error validasi per-field, contoh: {"email": ["The email field is required."]}
  /// Berguna untuk ditampilkan langsung di bawah TextField terkait.
  final Map<String, List<String>>? fieldErrors;

  /// Body response mentah (kalau ada). Beberapa endpoint (mis. POST
  /// /exams/start) menyisipkan key tambahan di luar schema Error standar
  /// ({message}) -- reason/batch_start_at/batch_end_at -- daripada bikin
  /// exception khusus per-fitur, key itu dibaca lewat getter di bawah.
  final Map<String, dynamic>? raw;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidationError => statusCode == 422;
  bool get isNotFound => statusCode == 404;

  /// 403 dari POST /exams/start ketika part Latihan Fokus sebelumnya
  /// belum diselesaikan.
  bool get isPreviousPartIncomplete =>
      isForbidden && raw?['reason'] == 'previous_part_incomplete';

  /// 422 dari POST /exams/start ketika try-out batch belum buka/sudah
  /// tutup. Null kalau bukan kasus ini.
  DateTime? get batchStartAt => _dateTimeFromRaw('batch_start_at');
  DateTime? get batchEndAt => _dateTimeFromRaw('batch_end_at');

  DateTime? _dateTimeFromRaw(String key) {
    final value = raw?[key];
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  @override
  String toString() => message;
}
