import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  LevelPendidikan? _selectedLevel;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await ref.read(authNotifierProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          passwordConfirmation: _passwordConfirmCtrl.text,
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          levelPendidikan: _selectedLevel?.name,
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });

    if (error == null) {
      // Registrasi berhasil TAPI user belum login otomatis — backend
      // mengirim email verifikasi dan login baru bisa dilakukan setelah
      // email diverifikasi. Arahkan ke layar "cek email".
      if (mounted) context.push('/check-email', extra: _emailCtrl.text.trim());
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.neutral400,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Buat Akun Baru',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutral900,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Isi datamu untuk mulai belajar di Xtracademy.',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 13),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.danger50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger600, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.danger700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionLabel('Data diri'),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.neutral400),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'nama@email.com',
                    prefixIcon: Icon(Icons.mail_outline, color: AppColors.neutral400),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP (opsional)',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.neutral400),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<LevelPendidikan>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Jenjang pendidikan (opsional)',
                    prefixIcon: Icon(Icons.school_outlined, color: AppColors.neutral400),
                  ),
                  items: const [
                    DropdownMenuItem(value: LevelPendidikan.sd, child: Text('SD')),
                    DropdownMenuItem(value: LevelPendidikan.smp, child: Text('SMP')),
                    DropdownMenuItem(value: LevelPendidikan.sma, child: Text('SMA')),
                    DropdownMenuItem(value: LevelPendidikan.mahasiswa, child: Text('Mahasiswa')),
                    DropdownMenuItem(value: LevelPendidikan.umum, child: Text('Umum')),
                  ],
                  onChanged: (v) => setState(() => _selectedLevel = v),
                ),
                const SizedBox(height: 24),
                _sectionLabel('Keamanan akun'),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'Minimal 8 karakter',
                    helperStyle: const TextStyle(color: AppColors.neutral400, fontSize: 12),
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neutral400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.neutral400,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password wajib diisi';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordConfirmCtrl,
                  obscureText: _obscurePasswordConfirm,
                  decoration: InputDecoration(
                    labelText: 'Konfirmasi password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.neutral400),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePasswordConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.neutral400,
                      ),
                      onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Konfirmasi password tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Daftar'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sudah punya akun?',
                      style: TextStyle(color: AppColors.neutral600, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Masuk'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}