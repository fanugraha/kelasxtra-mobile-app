// lib/features/enrollment/data/models/enrollment_model.dart
//
// Model Enrollment -- field & tipe cocok dengan schema Enrollment di
// kelasxtra-openapi.yaml (x-verified: source-code).
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../katalog/data/models/package_model.dart';

part 'enrollment_model.freezed.dart';
part 'enrollment_model.g.dart';

enum EnrollmentStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('active')
  active,
  @JsonValue('expired')
  expired,
}

@freezed
class EnrollmentModel with _$EnrollmentModel {
  const factory EnrollmentModel({
    required int id,
    required PackageModel package,
    required EnrollmentStatus status,
    // `is_active` HASIL dari Enrollment::isActive() di backend (bukan kolom
    // DB langsung) -- ini yang dipakai untuk pisah "Aktif" vs "Kedaluwarsa"
    // di UI, BUKAN [status], karena status=active tapi end_date sudah lewat
    // tetap mungkin terjadi kalau job expiry belum jalan.
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'start_date') String? startDate,
    @JsonKey(name: 'end_date') String? endDate,
  }) = _EnrollmentModel;

  const EnrollmentModel._();

  factory EnrollmentModel.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentModelFromJson(json);

  /// null = lifetime/tidak ada expiry (durationDays null di paket aslinya).
  bool get isLifetime => endDate == null;
}
