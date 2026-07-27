# KelasXtra Mobile (Flutter + Riverpod)

Struktur feature-first, dibangun dari `kelasxtra-openapi.yaml` (27 Juli 2026).

## Stack
- **State management**: Riverpod (generator, `@riverpod`)
- **Routing**: go_router, redirect otomatis berbasis `AuthState`
- **HTTP**: Dio + Retrofit (codegen)
- **Model**: Freezed + json_serializable
- **Token storage**: flutter_secure_storage
- **Checkout**: webview_flutter (Midtrans Snap **web** SDK — API ini belum expose Snap native mobile)

## Setup pertama kali
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Selama development, jalankan watcher supaya file `.g.dart`/`.freezed.dart` auto-update:
```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Yang sudah jadi
- ✅ Modul **Auth** lengkap: register, login (email + Google ID token), forgot/reset password,
  get/update profile, ganti password, logout, auto-restore session, auto-logout saat 401
  (menghormati sifat *single-session* backend).
- ✅ Core: Dio client + interceptor Bearer token, exception handler seragam (`ApiException`),
  konstanta semua endpoint (`ApiEndpoints`), router dengan auth guard.

## Yang perlu dilanjutkan
Setiap folder di `lib/features/<modul>/README.md` berisi pola yang harus diikuti — modul yang
belum diisi: katalog, transaksi, subscription, enrollment, exam_engine, latihan_fokus,
leaderboard, notifikasi, kelas_materi, privasi, tutor, beranda.

**Prioritas yang disarankan** (mengikuti alur pengguna):
1. `katalog` + `beranda` — supaya ada halaman setelah login
2. `enrollment` + `transaksi` — proses beli paket
3. `exam_engine` — inti aplikasi (ujian, timer per-section, anti-cheat)
4. `latihan_fokus`, `leaderboard`, `notifikasi`, `kelas_materi`, `privasi`, `tutor`

## Sebelum production
- [ ] Ganti `AppConfig.current` di `lib/core/config/env.dart` ke `Env.production`
- [ ] Isi `GOOGLE_CLIENT_ID` untuk Google Sign-In (native, hasilkan ID token untuk `/auth/google`)
- [ ] Ganti seed color & logo di `AppTheme`
- [ ] Beberapa endpoint di OpenAPI ditandai `x-verified: inferred` (mis. `/exam-attempts/{id}/review`,
      `/my-exams`, `/classes/{id}`) — strukturnya perlu dicek 1x panggilan nyata ke API sebelum
      dipakai untuk parsing model final.
