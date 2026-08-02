// lib/features/subscription/presentation/screens/subscription_format.dart
//
// Sama seperti transaksi_format.dart -- hand-rolled, bukan intl's
// DateFormat/NumberFormat.currency (butuh initializeDateFormatting('id_ID')
// yang belum ada di main.dart project ini).

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

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// "2026-08-02" atau "2026-08-02T00:00:00.000000Z" -> "2 Agu 2026"
String formatTanggalSingkat(String? dateString) {
  if (dateString == null) return '-';
  final date = DateTime.tryParse(dateString);
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day} ${_bulan[local.month - 1]} ${local.year}';
}

/// 30 -> "30 hari", 365 -> "1 tahun", 90 -> "3 bulan" (pembulatan kasar,
/// cukup buat label kartu plan).
String formatDurasi(int days) {
  if (days % 365 == 0 && days >= 365) {
    final years = days ~/ 365;
    return years == 1 ? '1 tahun' : '$years tahun';
  }
  if (days % 30 == 0 && days >= 30) {
    final months = days ~/ 30;
    return months == 1 ? '1 bulan' : '$months bulan';
  }
  return '$days hari';
}

