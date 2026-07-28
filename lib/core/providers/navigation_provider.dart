// lib/core/providers/navigation_provider.dart
//
// Index tab aktif di AppShell. Diletakkan di core/ (bukan di file
// app_shell.dart langsung) supaya fitur lain (mis. grid di Beranda yang
// mau pindah ke tab Latihan) bisa import provider ini tanpa memicu
// circular import dengan app_shell.dart (yang juga meng-import
// BerandaScreen).
//
// Cara pakai dari widget manapun:
//   ref.read(selectedTabIndexProvider.notifier).state = 1;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);
