// lib/core/utils/formatters.dart
//
// Formatter angka/tanggal kecil yang dipakai lintas modul (transaksi,
// subscription, katalog, beranda) -- sebelumnya terduplikasi persis sama
// di beberapa tempat (transaksi_format.dart, subscription_format.dart,
// _formatRupiah privat di beranda_screen.dart). Dikonsolidasi ke sini
// supaya modul baru (katalog, dst) tidak nambah copy lagi.
//
// Sengaja hand-rolled, bukan intl's DateFormat/NumberFormat.currency --
// itu butuh initializeDateFormatting('id_ID') dulu di main.dart yang belum
// ada di project ini, dan formatnya cukup sederhana untuk ditulis manual.

const _bulanSingkat = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

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

/// "2026-08-02T10:15:00.000000Z" -> "2 Agu 2026, 10:15"
String formatTanggal(String? isoString) {
  if (isoString == null) return '-';
  final date = DateTime.tryParse(isoString);
  if (date == null) return '-';
  final local = date.toLocal();
  final jam = local.hour.toString().padLeft(2, '0');
  final menit = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}, $jam:$menit';
}

/// "2026-08-02" atau "2026-08-02T00:00:00.000000Z" -> "2 Agu 2026"
String formatTanggalSingkat(String? dateString) {
  if (dateString == null) return '-';
  final date = DateTime.tryParse(dateString);
  if (date == null) return '-';
  final local = date.toLocal();
  return '${local.day} ${_bulanSingkat[local.month - 1]} ${local.year}';
}

/// 30 -> "30 hari", 365 -> "1 tahun", 90 -> "3 bulan" (pembulatan kasar,
/// cukup buat label kartu plan/paket).
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
