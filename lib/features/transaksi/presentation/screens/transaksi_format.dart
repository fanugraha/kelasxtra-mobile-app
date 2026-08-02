// lib/features/transaksi/presentation/screens/transaksi_format.dart
//
// Helper format kecil khusus modul ini. Sengaja tangan sendiri, bukan
// intl's DateFormat/NumberFormat.currency -- itu butuh
// initializeDateFormatting('id_ID') dulu di main.dart yang belum ada di
// project ini, dan formatnya cukup sederhana untuk ditulis manual.

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "2026-08-02T10:15:00.000000Z" -> "2 Agu 2026, 10:15"
String formatTanggal(String? isoString) {
  if (isoString == null) return '-';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '-';
  final local = date.toLocal();
  final jam = local.hour.toString().padLeft(2, '0');
  final menit = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_bulan[local.month - 1]} ${local.year}, $jam:$menit';
}

/// 150000.0 -> "Rp150.000"
String formatRupiah(double amount) {
  final rounded = amount.round();
  final digits = rounded.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
  }

  return 'Rp$buffer';
}

