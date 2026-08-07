// lib/features/privasi/presentation/screens/privasi_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/privasi_repository.dart';

class PrivasiScreen extends ConsumerWidget {
  const PrivasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.maybeWhen(authenticated: (u) => u, orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        backgroundColor: AppColors.neutral50,
        title: const Text('Privasi'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _HideFromLeaderboardTile(initialValue: user.hideFromLeaderboardFeed),
                ],
              ),
            ),
    );
  }
}

class _HideFromLeaderboardTile extends ConsumerStatefulWidget {
  const _HideFromLeaderboardTile({required this.initialValue});
  final bool initialValue;

  @override
  ConsumerState<_HideFromLeaderboardTile> createState() => _HideFromLeaderboardTileState();
}

class _HideFromLeaderboardTileState extends ConsumerState<_HideFromLeaderboardTile> {
  late bool _value = widget.initialValue;
  bool _isSaving = false;

  Future<void> _handleChanged(bool newValue) async {
    final previous = _value;
    // Optimistic update -- toggle terasa instan, di-revert kalau ternyata
    // gagal simpan ke server.
    setState(() {
      _value = newValue;
      _isSaving = true;
    });

    try {
      await ref.read(privasiRepositoryProvider).updatePrivacy(hideFromLeaderboardFeed: newValue);
      // PATCH /user/privacy cuma balikin {"message": ...}, bukan user
      // terbaru -- update UserModel lokal manual lewat setUser() supaya
      // authNotifierProvider (dipakai di mana-mana, termasuk kalau screen
      // ini dibuka lagi) langsung sinkron tanpa perlu refreshCurrentUser()
      // (network call tambahan yang tidak perlu untuk 1 field ini).
      final authNotifier = ref.read(authNotifierProvider.notifier);
      final currentUser = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (u) => u,
            orElse: () => null,
          );
      if (currentUser != null) {
        authNotifier.setUser(currentUser.copyWith(hideFromLeaderboardFeed: newValue));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _value = previous;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _value,
        onChanged: _isSaving ? null : _handleChanged,
        activeColor: AppColors.brand500,
        title: const Text(
          'Sembunyikan dari Feed Peringkat',
          style: TextStyle(color: AppColors.neutral900, fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Nama dan skormu tidak akan muncul di papan peringkat latihan soal mingguan '
          'kalau ini diaktifkan. Kamu tetap bisa mengerjakan latihan seperti biasa.',
          style: TextStyle(color: AppColors.neutral500, fontSize: 12, height: 1.4),
        ),
      ),
    );
  }
}
