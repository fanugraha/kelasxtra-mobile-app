// lib/features/exam_engine/data/models/my_exam_model.dart
//
// Model untuk GET /my-exams. x-verified: source-code -- dicocokkan langsung
// ke ExamController::myExams() di kelasxtra-backend (openapi.yaml masih
// `x-verified: inferred`/schema generik untuk endpoint ini).
//
// PENTING: endpoint ini CUMA daftar exam yang boleh diakses siswa (hasil
// filter AccessControlService::canAttemptExam(), lintas SEMUA paket yang
// dipunya) -- TIDAK ada info status pengerjaan (sudah dikerjakan/belum,
// skor) di payload-nya, beda dari asumsi awal "Riwayat Ujian". Status itu
// baru didapat per-exam lewat GET /exams/{exam}/summary (attempts_count,
// first_attempt, latest_attempt) -- makanya tap di MyExamsScreen tetap
// diarahkan ke ExamSummaryScreen yang sudah ada, bukan menampilkan status
// langsung di kartu list.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'my_exam_model.freezed.dart';
part 'my_exam_model.g.dart';

@freezed
class MyExamBank with _$MyExamBank {
  const factory MyExamBank({
    required int id,
    required String title,
    @JsonKey(name: 'questions_count') @Default(0) int questionsCount,
  }) = _MyExamBank;

  factory MyExamBank.fromJson(Map<String, dynamic> json) => _$MyExamBankFromJson(json);
}

@freezed
class MyExamItem with _$MyExamItem {
  const factory MyExamItem({
    required int id,
    required String title,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'passing_score') int? passingScore,
    @JsonKey(name: 'questions_count') int? questionsCount,
    @JsonKey(name: 'is_free_preview') @Default(false) bool isFreePreview,
    // Null kalau exam ini tidak terhubung ke bank soal manapun (edge case
    // konten belum lengkap) -- backend ambil program_ids[0] sebagai
    // representatif, TIDAK selalu berarti exam ini cuma 1 program.
    @JsonKey(name: 'program_id') int? programId,
    @JsonKey(name: 'program_ids') @Default(<int>[]) List<int> programIds,
    // >1 = exam ini gabungan beberapa Question Bank (mis. TWK+TIU+TKP
    // dalam 1 try-out) -- TETAP 1 attempt/1 nilai gabungan (lihat catatan
    // di ExamController::forPackage), bukan sinyal untuk modal pilih bank.
    @JsonKey(name: 'available_banks') @Default(<MyExamBank>[]) List<MyExamBank> availableBanks,
  }) = _MyExamItem;

  const MyExamItem._();

  factory MyExamItem.fromJson(Map<String, dynamic> json) => _$MyExamItemFromJson(json);
}
