// lib/features/kelas_materi/data/models/kelas_materi_model.dart
//
// x-verified STATUS PER ENDPOINT (lihat kelasxtra-openapi.yaml):
// - GET /classes            -> source-code (id, name, status, program_id,
//   is_accessible) -- ClassSummary di bawah AMAN dipakai apa adanya.
// - GET /materials/{id}     -> source-code (id, class_id, title, file_url,
//   type: pdf|video_link) -- MaterialItem di bawah AMAN dipakai apa adanya.
// - GET /classes/{id}       -> x-verified: inferred, DAN beda dari kasus
//   `question` di modul Tutor (yang MASIH dikasih parent object dengan tipe
//   jelas) -- di sini SELURUH body cuma "type: object" tanpa satupun
//   properti terdokumentasi. Summary endpoint cuma bilang isinya
//   "(+materials, +schedules, +tutor)".
//
// STRATEGI untuk ClassDetail (bagian yang inferred):
// 1. Field id/name/status/programId/isAccessible ditebak SAMA dengan
//    ClassSummary (masuk akal karena kemungkinan besar accessor Laravel-nya
//    ClassResource yang extends/reuse resource yang sama untuk list & show).
// 2. `materials` ditebak berupa list objek berbentuk sama seperti
//    MaterialItem (verified) -- karena kalaupun beda, field yang dipakai UI
//    (id, title, type) kemungkinan besar tetap ada dengan nama yang sama.
// 3. `schedules` BENAR-BENAR tidak ada petunjuk bentuknya sama sekali --
//    tidak ditebak jadi model spesifik. Disimpan sebagai List<dynamic> raw
//    dan screen merender apa adanya secara generik (key: value) supaya
//    tidak crash kalau bentuknya meleset, sekaligus tidak menyembunyikan
//    data dari user.
// 4. `tutor` ditebak {id, name} mengikuti pola TutorEssayAttemptUser yang
//    sudah dipakai di modul lain untuk representasi "person" ringkas.
// 5. SEMUA field kelas 2-4 nullable/default kosong -- kalau backend kirim
//    struktur berbeda, UI fallback ke "tidak tersedia" per-bagian, BUKAN
//    error/crash seluruh layar. Setelah dites dengan device asli dan log
//    Dio dicek, sanitasi ini WAJIB diperbaiki supaya cocok response asli
//    (sama seperti alur perbaikan questionText di modul Tutor kemarin).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'kelas_materi_model.freezed.dart';
part 'kelas_materi_model.g.dart';

/// GET /classes -- item list. x-verified: source-code.
@freezed
class ClassSummary with _$ClassSummary {
  const factory ClassSummary({
    required int id,
    required String name,
    required String status,
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'is_accessible') @Default(false) bool isAccessible,
  }) = _ClassSummary;

  factory ClassSummary.fromJson(Map<String, dynamic> json) => _$ClassSummaryFromJson(json);
}

/// GET /materials/{material} -- x-verified: source-code. Dipakai juga
/// sebagai tebakan bentuk item di ClassDetail.materials (lihat catatan di
/// atas file, poin 2).
@freezed
class MaterialItem with _$MaterialItem {
  const factory MaterialItem({
    required int id,
    @JsonKey(name: 'class_id') int? classId,
    required String title,
    @JsonKey(name: 'file_url') String? fileUrl,
    // enum: pdf | video_link -- disimpan String mentah (bukan enum Dart)
    // supaya nilai tak dikenal tidak bikin parsing gagal total, cuma
    // fallback ke tampilan generik di UI.
    String? type,
  }) = _MaterialItem;

  factory MaterialItem.fromJson(Map<String, dynamic> json) => _$MaterialItemFromJson(json);

  const MaterialItem._();

  bool get isPdf => type == 'pdf';
  bool get isVideoLink => type == 'video_link';
}

/// Representasi ringkas tutor pengampu kelas -- x-verified: UNVERIFIED,
/// tebakan pola {id, name} (lihat catatan poin 4).
@freezed
class ClassTutorRef with _$ClassTutorRef {
  const factory ClassTutorRef({
    int? id,
    String? name,
  }) = _ClassTutorRef;

  factory ClassTutorRef.fromJson(Map<String, dynamic> json) => _$ClassTutorRefFromJson(json);
}

/// GET /classes/{class} -- x-verified: UNVERIFIED (kecuali id/name/status/
/// programId/isAccessible yang dipinjam dari ClassSummary). Lihat catatan
/// panjang di atas file ini sebelum mengandalkan field apa pun di sini
/// untuk keputusan penting.
@freezed
class ClassDetail with _$ClassDetail {
  const factory ClassDetail({
    required int id,
    required String name,
    String? status,
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'is_accessible') @Default(true) bool isAccessible,
    // true kalau backend memang tidak kirim field ini sama sekali (bukan
    // array kosong) -- dipakai screen untuk membedakan "belum ada materi"
    // vs "field ini ternyata bukan `materials`, cek log Dio".
    @Default(<MaterialItem>[]) List<MaterialItem> materials,
    // Raw & tidak dimodelkan sama sekali -- lihat catatan poin 3.
    @Default(<dynamic>[]) List<dynamic> schedulesRaw,
    ClassTutorRef? tutor,
  }) = _ClassDetail;

  factory ClassDetail.fromJson(Map<String, dynamic> json) =>
      _$ClassDetailFromJson(sanitizeClassDetailJson(json));
}

/// Menyuntik ulang key jadi bentuk yang predictable SEBELUM fromJson
/// standar dipanggil -- pola yang sama dipakai di tutor_essay_model.dart
/// (sanitizeEssayQueueJson) supaya freezed toJson() tetap ter-generate
/// normal untuk class ini.
Map<String, dynamic> sanitizeClassDetailJson(Map<String, dynamic> json) {
  final sanitized = Map<String, dynamic>.from(json);

  final materialsRaw = sanitized['materials'];
  if (materialsRaw is! List) {
    sanitized['materials'] = <dynamic>[];
  }

  final schedulesRaw = sanitized['schedules'];
  sanitized['schedulesRaw'] = schedulesRaw is List ? schedulesRaw : <dynamic>[];

  return sanitized;
}

