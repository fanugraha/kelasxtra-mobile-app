mkdir -p lib/features/katalog/data lib/features/katalog/data/models lib/features/katalog/data/repositories lib/features/katalog/presentation/screens lib/features/katalog/presentation/widgets lib/features/subscription/presentation/screens

cat > lib/features/katalog/data/models/promo_model.dart << 'EOF_PROMO_MODEL_DART'
// lib/features/katalog/data/models/promo_model.dart
//
// Model Promo -- dipakai di riwayat transaksi (transaction.promo) dan nanti
// checkout (promos/validate). Field & tipe cocok dengan `promos` table
// (dicocokkan ke migration, x-verified: source-code).
import 'package:freezed_annotation/freezed_annotation.dart';

part 'promo_model.freezed.dart';
part 'promo_model.g.dart';

enum PromoDiscountType {
  @JsonValue('percentage')
  percentage,
  @JsonValue('fixed')
  fixed,
}

/// Laravel meng-cast kolom decimal sebagai STRING saat serialize ke JSON
/// (mis. "10000.00"), bukan number murni -- sama seperti price di Package.
double _decimalFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return double.parse(value.toString());
}

@freezed
class PromoModel with _$PromoModel {
  const factory PromoModel({
    required int id,
    required String title,
    String? description,
    @JsonKey(name: 'discount_type') required PromoDiscountType discountType,
    @JsonKey(name: 'discount_value', fromJson: _decimalFromJson) required double discountValue,
    required String code,
  }) = _PromoModel;

  const PromoModel._();

  factory PromoModel.fromJson(Map<String, dynamic> json) => _$PromoModelFromJson(json);

  /// Label siap tampil, mis. "Diskon 10%" atau "Potongan Rp20.000".
  String get discountLabel => discountType == PromoDiscountType.percentage
      ? 'Diskon ${discountValue.toStringAsFixed(0)}%'
      : 'Potongan Rp${discountValue.toStringAsFixed(0)}';
}

/// POST /promos/validate -- x-verified: source-code. Response 200 kalau
/// kode valid untuk package_id/plan_id yang dikirim (belum bikin transaksi
/// apapun, murni pre-check untuk tombol "Terapkan"). 404 (kode tidak
/// ditemukan) & 422 (kedaluwarsa/kuota habis/new_user_only/dll) ditangani
/// sebagai ApiException biasa di repository -- pesannya sudah dari
/// backend, tidak perlu dipetakan ulang di client.
@freezed
class PromoValidationResult with _$PromoValidationResult {
  const factory PromoValidationResult({
    required PromoModel promo,
    @JsonKey(name: 'base_price', fromJson: _decimalFromJson) required double basePrice,
    @JsonKey(name: 'discount_amount', fromJson: _decimalFromJson) required double discountAmount,
    @JsonKey(name: 'final_amount', fromJson: _decimalFromJson) required double finalAmount,
  }) = _PromoValidationResult;

  factory PromoValidationResult.fromJson(Map<String, dynamic> json) =>
      _$PromoValidationResultFromJson(json);
}


EOF_PROMO_MODEL_DART

cat > lib/features/katalog/data/katalog_api_service.dart << 'EOF_KATALOG_API_SERVICE_DART'
// lib/features/katalog/data/katalog_api_service.dart
//
// Panggilan HTTP mentah untuk katalog paket (beli baru) -- GET /packages
// TIDAK punya filter `type` di server (cuma `program_id`, lihat spec),
// jadi filter per PackageType (reguler=Tryout, latihan_soal=Latihan Soal)
// dilakukan client-side di provider/screen, bukan di query param.
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/package_model.dart';
import 'models/promo_model.dart';

part 'katalog_api_service.g.dart';

class KatalogApiService {
  KatalogApiService(this._dio);

  final Dio _dio;

  /// GET /packages -- daftar semua paket yang bisa dibeli (bukan yang
  /// sudah dimiliki user -- itu /my-packages, lihat EnrollmentRepository).
  Future<List<PackageModel>> getPackages({int? programId}) async {
    final response = await _dio.get(
      ApiEndpoints.packages,
      queryParameters: programId != null ? {'program_id': programId} : null,
    );
    final data = response.data as List<dynamic>;
    return data.map((e) => PackageModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    final response = await _dio.get(ApiEndpoints.packageDetail(packageId));
    return PackageModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /promos/validate -- pre-check kode promo (tombol "Terapkan"),
  /// TIDAK bikin transaksi. Salah satu dari [packageId]/[planId] wajib
  /// diisi (sama seperti aturan checkout) -- dibiarkan backend yang
  /// validasi kombinasinya, client tidak menduplikasi aturan itu.
  Future<PromoValidationResult> validatePromo({
    required String code,
    int? packageId,
    int? planId,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.promosValidate,
      data: {
        'code': code,
        if (packageId != null) 'package_id': packageId,
        if (planId != null) 'plan_id': planId,
      },
    );
    return PromoValidationResult.fromJson(response.data as Map<String, dynamic>);
  }
}

@Riverpod(keepAlive: true)
KatalogApiService katalogApiService(KatalogApiServiceRef ref) {
  return KatalogApiService(ref.watch(dioProvider));
}

EOF_KATALOG_API_SERVICE_DART

cat > lib/features/katalog/data/repositories/katalog_repository.dart << 'EOF_KATALOG_REPOSITORY_DART'
// lib/features/katalog/data/repositories/katalog_repository.dart
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/api_exception.dart';
import '../katalog_api_service.dart';
import '../models/package_model.dart';
import '../models/promo_model.dart';

part 'katalog_repository.g.dart';

class KatalogRepository {
  KatalogRepository(this._api);

  final KatalogApiService _api;

  Future<List<PackageModel>> getPackages({int? programId}) async {
    try {
      return await _api.getPackages(programId: programId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<PackageModel> getPackageDetail(int packageId) async {
    try {
      return await _api.getPackageDetail(packageId);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Return (result, null) kalau valid, (null, pesan error) kalau tidak --
  /// pola sama seperti TutorRepository.gradeEssay: kode 404/422 BUKAN
  /// exception yang perlu ditangani beda-beda oleh UI, cukup pesannya saja
  /// (backend sudah kasih pesan Indonesia yang jelas: "kode tidak
  /// ditemukan", "kedaluwarsa", dll).
  Future<(PromoValidationResult?, String?)> validatePromo({
    required String code,
    int? packageId,
    int? planId,
  }) async {
    try {
      final result = await _api.validatePromo(code: code, packageId: packageId, planId: planId);
      return (result, null);
    } on DioException catch (e) {
      return (null, ApiException.fromDioException(e).message);
    }
  }
}

@riverpod
KatalogRepository katalogRepository(KatalogRepositoryRef ref) {
  return KatalogRepository(ref.watch(katalogApiServiceProvider));
}

EOF_KATALOG_REPOSITORY_DART

cat > lib/features/katalog/presentation/widgets/promo_code_field.dart << 'EOF_PROMO_CODE_FIELD_DART'
// lib/features/katalog/presentation/widgets/promo_code_field.dart
//
// Widget input kode promo + tombol "Terapkan", dipakai di dua tempat:
// _PackageDetailSheet (katalog_screen.dart, beli paket) dan
// _PlanDetailSheet (langganan_screen.dart, beli subscription) -- makanya
// diletakkan di katalog/presentation/widgets (bukan di dalam salah satu
// screen) supaya tidak ada logic tervalidasi promo yang terduplikasi
// antara dua flow itu.
//
// Sengaja TIDAK auto-validate saat mengetik (debounce dsb) -- endpoint ini
// rate-limited 20/menit per spec, dan pola "tombol Terapkan" eksplisit
// lebih jelas buat user daripada validasi diam-diam di belakang layar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/promo_model.dart';
import '../../data/repositories/katalog_repository.dart';

class PromoCodeField extends ConsumerStatefulWidget {
  const PromoCodeField({
    super.key,
    this.packageId,
    this.planId,
    required this.onResultChanged,
  }) : assert(
          (packageId == null) != (planId == null),
          'Isi salah satu packageId ATAU planId, tidak boleh dua-duanya atau kosong dua-duanya',
        );

  final int? packageId;
  final int? planId;

  /// Dipanggil dengan hasil validasi (buat parent update harga & simpan
  /// kode buat dikirim ke checkout), atau null kalau promo dibatalkan
  /// (tombol "Hapus" ditekan) -- BUKAN dipanggil saat gagal validasi,
  /// error cukup ditampilkan inline di widget ini sendiri.
  final ValueChanged<PromoValidationResult?> onResultChanged;

  @override
  ConsumerState<PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends ConsumerState<PromoCodeField> {
  final _controller = TextEditingController();
  bool _isValidating = false;
  String? _errorText;
  PromoValidationResult? _applied;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Masukkan kode promo dulu.');
      return;
    }

    setState(() {
      _isValidating = true;
      _errorText = null;
    });

    final (result, error) = await ref.read(katalogRepositoryProvider).validatePromo(
          code: code,
          packageId: widget.packageId,
          planId: widget.planId,
        );

    if (!mounted) return;
    setState(() {
      _isValidating = false;
      _applied = result;
      _errorText = error;
    });

    widget.onResultChanged(result);
  }

  void _clear() {
    setState(() {
      _applied = null;
      _errorText = null;
      _controller.clear();
    });
    widget.onResultChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_applied != null) {
      return _AppliedPromoCard(result: _applied!, onRemove: _clear);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                enabled: !_isValidating,
                decoration: InputDecoration(
                  hintText: 'Kode promo (opsional)',
                  hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 13),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.neutral200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _errorText != null ? AppColors.danger600 : AppColors.neutral200),
                  ),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.neutral900),
                onSubmitted: (_) => _isValidating ? null : _apply(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _isValidating ? null : _apply,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _isValidating
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Terapkan'),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 6),
          Text(_errorText!, style: const TextStyle(color: AppColors.danger600, fontSize: 12)),
        ],
      ],
    );
  }
}

class _AppliedPromoCard extends StatelessWidget {
  const _AppliedPromoCard({required this.result, required this.onRemove});
  final PromoValidationResult result;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success600.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: AppColors.success700, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.promo.code} diterapkan',
                  style: const TextStyle(color: AppColors.success700, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  result.promo.discountLabel,
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: AppColors.neutral500),
            tooltip: 'Hapus kode promo',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

EOF_PROMO_CODE_FIELD_DART

cat > lib/features/katalog/presentation/screens/katalog_screen.dart << 'EOF_KATALOG_SCREEN_DART'
// lib/features/katalog/presentation/screens/katalog_screen.dart
//
// Katalog paket beli-baru -- GET /packages (semua paket publik), difilter
// client-side ke PackageType.reguler (Tryout) & PackageType.latihanSoal
// (Latihan Soal) saja. privat/group SENGAJA disembunyikan -- itu paket
// kelas 1-on-1/grup dengan tutor, belum ada modul untuk itu (kelas_materi
// & tutor masih README-only, lihat dokumen status project).
//
// Status kepemilikan (badge "Dimiliki") dicek silang ke enrollmentNotifierProvider
// (cache /my-packages) -- tidak ada network call tambahan untuk itu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../enrollment/presentation/providers/enrollment_provider.dart';
import '../../../transaksi/data/repositories/transaksi_repository.dart';
import '../../../transaksi/presentation/screens/checkout_webview_screen.dart';
import '../../data/models/promo_model.dart';
import '../providers/katalog_provider.dart';
import '../widgets/promo_code_field.dart';

class KatalogScreen extends ConsumerStatefulWidget {
  const KatalogScreen({super.key, this.initialFilter});

  /// Prefilter saat masuk dari tempat yang sudah tahu konteksnya, mis. dari
  /// tombol kosong di TryoutScreen (filter = reguler). null = tampilkan
  /// semua jenis yang relevan.
  final PackageType? initialFilter;

  @override
  ConsumerState<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends ConsumerState<KatalogScreen> {
  PackageType? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(katalogNotifierProvider);
    final enrollmentsAsync = ref.watch(enrollmentNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Katalog Paket'),
      ),
      body: packagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException ? error.message : 'Gagal memuat katalog paket',
          onRetry: () => ref.read(katalogNotifierProvider.notifier).refresh(),
        ),
        data: (packages) {
          final relevant = packages
              .where((p) => p.type == PackageType.reguler || p.type == PackageType.latihanSoal)
              .toList();
          final filtered =
              _filter == null ? relevant : relevant.where((p) => p.type == _filter).toList();

          final ownedActiveIds = enrollmentsAsync.valueOrNull
                  ?.where((e) => e.isActive)
                  .map((e) => e.package.id)
                  .toSet() ??
              const <int>{};

          return RefreshIndicator(
            onRefresh: () => ref.read(katalogNotifierProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _FilterChips(
                  selected: _filter,
                  onChanged: (type) => setState(() => _filter = type),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const _EmptyFilterState()
                else
                  for (final package in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PackageCard(
                        package: package,
                        isOwned: ownedActiveIds.contains(package.id),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});
  final PackageType? selected;
  final ValueChanged<PackageType?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(label: 'Semua', isSelected: selected == null, onTap: () => onChanged(null)),
          const SizedBox(width: 8),
          _Chip(
            label: 'Tryout',
            isSelected: selected == PackageType.reguler,
            onTap: () => onChanged(PackageType.reguler),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Latihan Soal',
            isSelected: selected == PackageType.latihanSoal,
            onTap: () => onChanged(PackageType.latihanSoal),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand500 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.brand500 : AppColors.neutral200),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.neutral700,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PackageCard extends ConsumerStatefulWidget {
  const _PackageCard({required this.package, required this.isOwned});
  final PackageModel package;
  final bool isOwned;

  @override
  ConsumerState<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends ConsumerState<_PackageCard> {
  bool _isBuying = false;

  Future<void> _handleBeli({String? promoCode}) async {
    setState(() => _isBuying = true);
    try {
      final transaction = await ref
          .read(transaksiRepositoryProvider)
          .checkoutPackage(widget.package.id, promoCode: promoCode);
      final token = transaction.snapToken;
      if (token == null) throw Exception('Token pembayaran tidak tersedia. Coba lagi.');

      if (!mounted) return;
      await context.push<CheckoutResult>(
        '/checkout',
        extra: CheckoutArgs(transactionId: transaction.id, snapToken: token),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isBuying = false);
    }
  }

  void _openDetail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PackageDetailSheet(
        package: widget.package,
        isOwned: widget.isOwned,
        isBuying: _isBuying,
        onBeli: (promoCode) {
          Navigator.of(sheetContext).pop();
          _handleBeli(promoCode: promoCode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final hasDiscount = package.hasDiscount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neutral200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: package.bannerImageUrl != null
                  ? Image.network(
                      package.bannerImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PackagePlaceholderIcon(type: package.type),
                    )
                  : _PackagePlaceholderIcon(type: package.type),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutral900,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          formatRupiah(package.effectivePrice),
                          style: const TextStyle(
                            color: AppColors.brand600,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            formatRupiah(package.price),
                            style: const TextStyle(
                              color: AppColors.neutral400,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    widget.isOwned
                        ? const _OwnedBadge()
                        : SizedBox(
                            height: 30,
                            child: FilledButton(
                              onPressed: _isBuying ? null : _handleBeli,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              child: _isBuying
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Beli'),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagePlaceholderIcon extends StatelessWidget {
  const _PackagePlaceholderIcon({required this.type});
  final PackageType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.neutral100,
      alignment: Alignment.center,
      child: Icon(
        type == PackageType.reguler ? Icons.timer_outlined : Icons.topic_outlined,
        color: AppColors.neutral400,
      ),
    );
  }
}

class _OwnedBadge extends StatelessWidget {
  const _OwnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.success50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: AppColors.success700),
          SizedBox(width: 4),
          Text(
            'Dimiliki',
            style: TextStyle(color: AppColors.success700, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PackageDetailSheet extends StatefulWidget {
  const _PackageDetailSheet({
    required this.package,
    required this.isOwned,
    required this.isBuying,
    required this.onBeli,
  });

  final PackageModel package;
  final bool isOwned;
  final bool isBuying;

  /// Dipanggil dengan kode promo yang sedang diterapkan (null kalau tidak
  /// ada) begitu tombol "Beli Sekarang" ditekan.
  final ValueChanged<String?> onBeli;

  @override
  State<_PackageDetailSheet> createState() => _PackageDetailSheetState();
}

class _PackageDetailSheetState extends State<_PackageDetailSheet> {
  PromoValidationResult? _promo;

  @override
  Widget build(BuildContext context) {
    final package = widget.package;
    final isOwned = widget.isOwned;
    final isBuying = widget.isBuying;
    final onBeli = widget.onBeli;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (package.bannerImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    package.bannerImageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                package.name,
                style: const TextStyle(
                  color: AppColors.neutral900,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    formatRupiah(_promo?.finalAmount ?? package.effectivePrice),
                    style: const TextStyle(
                      color: AppColors.brand600,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  // Kalau promo diterapkan, yang dicoret adalah harga SEBELUM
                  // promo (effectivePrice, yang sudah termasuk discount_price
                  // paket kalau ada) -- bukan package.price mentah, supaya
                  // tidak terlihat seperti diskon dobel yang salah hitung.
                  if (_promo != null || package.hasDiscount) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatRupiah(_promo != null ? package.effectivePrice : package.price),
                      style: const TextStyle(
                        color: AppColors.neutral400,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
              if (package.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  package.description!,
                  style: const TextStyle(color: AppColors.neutral600, fontSize: 13, height: 1.5),
                ),
              ],
              if (package.features != null && package.features!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Yang kamu dapat',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final feature in package.features!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check, size: 16, color: AppColors.success600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (package.materi != null && package.materi!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Materi yang dicakup',
                  style: TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final materi in package.materi!)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          materi,
                          style: const TextStyle(color: AppColors.neutral700, fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ],
              if (!isOwned) ...[
                const SizedBox(height: 20),
                const Text(
                  'Kode Promo',
                  style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                PromoCodeField(
                  packageId: package.id,
                  onResultChanged: (result) => setState(() => _promo = result),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: isOwned
                    ? const _OwnedBadge()
                    : FilledButton(
                        onPressed: isBuying ? null : () => onBeli(_promo?.promo.code),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: const Text('Beli Sekarang'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(
        child: Text(
          'Belum ada paket untuk kategori ini.',
          style: TextStyle(color: AppColors.neutral500, fontSize: 13),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral900, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

EOF_KATALOG_SCREEN_DART

cat > lib/features/subscription/presentation/screens/langganan_screen.dart << 'EOF_LANGGANAN_SCREEN_DART'
// lib/features/subscription/presentation/screens/langganan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../katalog/data/models/promo_model.dart';
import '../../../katalog/presentation/widgets/promo_code_field.dart';
import '../../../transaksi/data/repositories/transaksi_repository.dart';
import '../../../transaksi/presentation/screens/checkout_webview_screen.dart';
import '../providers/subscription_provider.dart';
import 'subscription_format.dart';

class LangganganScreen extends ConsumerWidget {
  const LangganganScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Langganan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(mySubscriptionNotifierProvider.notifier).refresh(),
            ref.read(subscriptionPlansNotifierProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: const [
            _MySubscriptionSection(),
            SizedBox(height: 24),
            _PlansSection(),
          ],
        ),
      ),
    );
  }
}

class _MySubscriptionSection extends ConsumerWidget {
  const _MySubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(mySubscriptionNotifierProvider);

    return subAsync.when(
      loading: () => Container(
        height: 88,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Gagal memuat status langganan', style: TextStyle(color: AppColors.neutral600, fontSize: 12.5)),
            ),
            TextButton(
              onPressed: () => ref.read(mySubscriptionNotifierProvider.notifier).refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (subscription) {
        if (subscription == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.neutral100, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.neutral500, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kamu belum berlangganan. Pilih paket di bawah untuk akses penuh.',
                    style: TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }

        final plan = subscription.plan;
        final coverageLabel = plan.isFixedProgram
            ? plan.program?.name ?? '-'
            : '${subscription.coveredProgramIds.length} program dipilih';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brand600, AppColors.brand500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Langganan Aktif', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                plan.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Mencakup: $coverageLabel',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (subscription.endDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Berlaku sampai ${formatTanggalSingkat(subscription.endDate)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlansSection extends ConsumerWidget {
  const _PlansSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Paket Langganan',
          style: TextStyle(color: AppColors.neutral900, fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        plansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.wifi_off_outlined, color: AppColors.neutral400, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Gagal memuat paket langganan', style: TextStyle(color: AppColors.neutral600, fontSize: 12.5)),
                ),
                TextButton(
                  onPressed: () => ref.read(subscriptionPlansNotifierProvider.notifier).refresh(),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Belum ada paket langganan yang tersedia saat ini.',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 12.5),
                ),
              );
            }

            return Column(
              children: [
                for (final plan in plans) ...[
                  _PlanCard(plan: plan),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final SubscriptionPlanModel plan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showPlanDetail(context, plan),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: plan.isFeatured ? AppColors.brand500 : AppColors.neutral200, width: plan.isFeatured ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          style: const TextStyle(color: AppColors.neutral900, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (plan.isFeatured) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.gold100, borderRadius: BorderRadius.circular(6)),
                          child: const Text('Populer', style: TextStyle(color: AppColors.gold600, fontSize: 9.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  if (plan.tagline != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      plan.tagline!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.neutral500, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${formatRupiah(plan.price)} / ${formatDurasi(plan.durationDays)}',
                    style: const TextStyle(color: AppColors.brand600, fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.neutral400, size: 18),
          ],
        ),
      ),
    );
  }
}

void _showPlanDetail(BuildContext context, SubscriptionPlanModel plan) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => _PlanDetailSheet(plan: plan),
  );
}

class _PlanDetailSheet extends ConsumerStatefulWidget {
  const _PlanDetailSheet({required this.plan});
  final SubscriptionPlanModel plan;

  @override
  ConsumerState<_PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends ConsumerState<_PlanDetailSheet> {
  bool _isCheckingOut = false;
  PromoValidationResult? _promo;

  Future<void> _handleBerlangganan() async {
    final plan = widget.plan;

    // Plan multi-select (program_slot_count terisi) butuh UI pemilihan
    // program yang belum dibangun -- daripada checkout dengan program_ids
    // asal/kosong dan kena 422 membingungkan, kasih tau jelas di sini.
    if (!plan.isFixedProgram) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Belum tersedia'),
          content: Text(
            'Plan ini butuh memilih ${plan.programSlotCount} program terlebih dulu -- fitur pemilihan program masih dalam pengembangan.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Oke')),
          ],
        ),
      );
      return;
    }

    setState(() => _isCheckingOut = true);
    try {
      final transaction = await ref
          .read(transaksiRepositoryProvider)
          .checkoutPlan(plan.id, promoCode: _promo?.promo.code);
      final token = transaction.snapToken;
      if (token == null) throw Exception('Token pembayaran tidak tersedia. Coba lagi.');

      if (!mounted) return;
      // Sengaja TIDAK nutup bottom sheet dulu -- context.push jalan di atas
      // sheet yang masih ada (sheet-nya cuma ketutup visual, bukan
      // di-dispose), begitu CheckoutWebViewScreen pop balik baru sheet ini
      // ditutup manual di bawah. Menghindari masalah context defunct kalau
      // sheet ditutup duluan sebelum push selesai.
      await context.push<CheckoutResult>(
        '/checkout',
        extra: CheckoutArgs(transactionId: transaction.id, snapToken: token),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.neutral200, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(plan.name, style: const TextStyle(color: AppColors.neutral900, fontSize: 17, fontWeight: FontWeight.w700)),
            if (plan.tagline != null) ...[
              const SizedBox(height: 4),
              Text(plan.tagline!, style: const TextStyle(color: AppColors.neutral500, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${formatRupiah(_promo?.finalAmount ?? plan.price)} / ${formatDurasi(plan.durationDays)}',
                  style: const TextStyle(color: AppColors.brand600, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (_promo != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(plan.price),
                    style: const TextStyle(
                      color: AppColors.neutral400,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            if (plan.description != null) ...[
              const SizedBox(height: 12),
              Text(plan.description!, style: const TextStyle(color: AppColors.neutral700, fontSize: 13, height: 1.5)),
            ],
            if (plan.features != null && plan.features!.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final feature in plan.features!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(feature, style: const TextStyle(color: AppColors.neutral700, fontSize: 12.5, height: 1.35)),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Kode Promo',
              style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            PromoCodeField(
              planId: plan.id,
              onResultChanged: (result) => setState(() => _promo = result),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isCheckingOut ? null : _handleBerlangganan,
                icon: _isCheckingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(_isCheckingOut ? 'Menyiapkan pembayaran...' : 'Berlangganan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

EOF_LANGGANAN_SCREEN_DART

echo 'Fitur Kode Promo (validate + input di checkout paket & langganan) selesai dibangun.'