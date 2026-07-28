// lib/features/akun/presentation/screens/edit_profil_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class EditProfilScreen extends ConsumerStatefulWidget {
  const EditProfilScreen({super.key});

  @override
  ConsumerState<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends ConsumerState<EditProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  LevelPendidikan? _levelPendidikan;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (u) => u,
          orElse: () => null,
        );
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _levelPendidikan = user?.levelPendidikan;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await ref.read(authNotifierProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          levelPendidikan: _levelPendidikan?.apiValue,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Edit Profil',
          style: TextStyle(color: AppColors.neutral900, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger600, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // CATATAN: email SENGAJA tidak ada di form ini -- PUT
                // /auth/profile di backend memang tidak menerima field
                // email (lihat komentar di AuthApiService.updateProfile).
                // Ganti email butuh alur terpisah (verifikasi ulang) yang
                // belum ada endpoint-nya sama sekali di spec saat ini.
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.neutral400),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
                    if (v.trim().length < 3) return 'Nama minimal 3 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP (opsional)',
                    hintText: '08xxxxxxxxxx',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.neutral400),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LevelPendidikan>(
                  value: _levelPendidikan,
                  decoration: const InputDecoration(
                    labelText: 'Jenjang Pendidikan (opsional)',
                    prefixIcon: Icon(Icons.school_outlined, color: AppColors.neutral400),
                  ),
                  items: LevelPendidikan.values
                      .map((level) => DropdownMenuItem(value: level, child: Text(level.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _levelPendidikan = value),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label tampilan + nilai yang dikirim ke API untuk tiap jenjang pendidikan.
/// TODO: [apiValue] sengaja DITULIS MANUAL persis sama dengan @JsonValue di
/// UserModel (lib/features/auth/data/models/user_model.dart) -- enum plain
/// ini TIDAK dilalui json_serializable jadi tidak auto-sync. Kalau enum
/// LevelPendidikan di user_model.dart berubah/ditambah, WAJIB update
/// extension ini juga secara manual atau dropdown akan mengirim value yang
/// salah ke backend tanpa error compile apapun.
extension LevelPendidikanLabel on LevelPendidikan {
  String get label {
    switch (this) {
      case LevelPendidikan.sd:
        return 'SD';
      case LevelPendidikan.smp:
        return 'SMP';
      case LevelPendidikan.sma:
        return 'SMA/SMK';
      case LevelPendidikan.mahasiswa:
        return 'Mahasiswa';
      case LevelPendidikan.umum:
        return 'Umum';
    }
  }

  String get apiValue {
    switch (this) {
      case LevelPendidikan.sd:
        return 'sd';
      case LevelPendidikan.smp:
        return 'smp';
      case LevelPendidikan.sma:
        return 'sma';
      case LevelPendidikan.mahasiswa:
        return 'mahasiswa';
      case LevelPendidikan.umum:
        return 'umum';
    }
  }
}
