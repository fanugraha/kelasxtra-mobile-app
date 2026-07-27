import 'package:dio/dio.dart';

/// Representasi error API yang seragam, dipetakan dari response Laravel:
/// { "message": "...", "errors": { "field": ["..."] } }
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.fieldErrors,
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
    );
  }

  final String message;
  final int? statusCode;

  /// Error validasi per-field, contoh: {"email": ["The email field is required."]}
  /// Berguna untuk ditampilkan langsung di bawah TextField terkait.
  final Map<String, List<String>>? fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isValidationError => statusCode == 422;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}
