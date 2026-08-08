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

