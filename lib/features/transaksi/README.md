# Modul: transaksi

Ikuti pola yang sama seperti modul `auth`:

1. `data/models/` — model Freezed sesuai schema di kelasxtra-openapi.yaml
2. `data/*_api_service.dart` — interface Retrofit (anotasi @RestApi, @GET/@POST/dst)
3. `data/repositories/` — bungkus API service, lempar ApiException
4. `presentation/providers/` — Riverpod Notifier/AsyncNotifier (@riverpod)
5. `presentation/screens/` — UI, konsumsi provider via ConsumerWidget
6. `presentation/widgets/` — widget reusable khusus modul ini

Lihat lib/features/auth untuk referensi lengkap.
