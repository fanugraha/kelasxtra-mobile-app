// lib/features/katalog/data/models/package_model.dart
//
// Model Package -- dipakai bersama oleh katalog & beranda (packages/recommended,
// packages, packages/focus-topics, packages/{package} semua balikin bentuk ini).
// Field & tipe cocok dengan schema Package di kelasxtra-openapi.yaml, yang
// ditandai x-verified: source-code (dicocokkan ke `packages` table).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'package_model.freezed.dart';
part 'package_model.g.dart';

/// Laravel meng-cast kolom decimal (price, discount_price) sebagai STRING
/// saat di-serialize ke JSON (mis. "20000.00"), bukan number murni.
/// Converter ini menerima String maupun num agar fromJson tidak crash.
double _priceFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

double? _nullablePriceFromJson(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

enum PackageType {
  @JsonValue('privat')
  privat,
  @JsonValue('group')
  group,
  @JsonValue('latihan_soal')
  latihanSoal,
  @JsonValue('reguler')
  reguler,
}

@freezed
class PackageProgram with _$PackageProgram {
  const factory PackageProgram({
    required int id,
    required String name,
    String? slug,
    String? icon,
  }) = _PackageProgram;

  factory PackageProgram.fromJson(Map<String, dynamic> json) =>
      _$PackageProgramFromJson(json);
}

@freezed
class PackageTaxonomy with _$PackageTaxonomy {
  const factory PackageTaxonomy({
    required int id,
    @JsonKey(name: 'program_id') int? programId,
    required String type,
    String? code,
    required String name,
    @JsonKey(name: 'passing_grade') int? passingGrade,
    @JsonKey(name: 'requires_passage') bool? requiresPassage,
  }) = _PackageTaxonomy;

  factory PackageTaxonomy.fromJson(Map<String, dynamic> json) =>
      _$PackageTaxonomyFromJson(json);
}

@freezed
class PackageModel with _$PackageModel {
  const factory PackageModel({
    required int id,
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'taxonomy_id') int? taxonomyId,
    required String name,
    required PackageType type,
    @JsonKey(name: 'is_focus_topic') @Default(false) bool isFocusTopic,
    @JsonKey(name: 'focus_taxonomy_id') int? focusTaxonomyId,
    @JsonKey(fromJson: _priceFromJson) required double price,
    // Nullable sesuai spec (nullable: true) -- jangan @Default 0, karena
    // null di sini artinya "tidak ada diskon", beda makna dari "diskon 0".
    @JsonKey(name: 'discount_price', fromJson: _nullablePriceFromJson) double? discountPrice,
    @JsonKey(name: 'duration_days') int? durationDays,
    String? description,
    // Nullable, bukan @Default([]) -- spec eksplisit menandai nullable:true
    // untuk features/materi (JSON array yang bisa null di DB).
    List<String>? features,
    List<String>? materi,
    @JsonKey(name: 'banner_image_url') String? bannerImageUrl,
    PackageProgram? program,
    PackageTaxonomy? taxonomy,
    @JsonKey(name: 'focus_taxonomy') PackageTaxonomy? focusTaxonomy,
  }) = _PackageModel;

  factory PackageModel.fromJson(Map<String, dynamic> json) =>
      _$PackageModelFromJson(json);
}

extension PackagePriceX on PackageModel {
  /// Harga yang berlaku ditampilkan ke user (discount_price kalau ada).
  double get effectivePrice => discountPrice ?? price;

  bool get hasDiscount => discountPrice != null && discountPrice! < price;
}