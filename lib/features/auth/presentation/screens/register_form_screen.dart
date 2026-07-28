import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Layar 2+3 (digabung): wizard registrasi manual dengan email.
/// Step 1 — nama & email. Step 2 — password & konfirmasi password.
/// Back dari step 2 kembali ke step 1 (bukan keluar dari form);
/// back dari step 1 pop keluar dari alur register (ke RegisterScreen).
class RegisterFormScreen extends ConsumerStatefulWidget {
  const RegisterFormScreen({super.key});

  @override
  ConsumerState<RegisterFormScreen> createState() => _RegisterFormScreenState();
}

class _RegisterFormScreenState extends ConsumerState<RegisterFormScreen> {
  final _pageController = PageController();
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  int _currentStep = 0;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    if (!(_step1FormKey.currentState?.validate() ?? false)) return;
    setState(() => _errorMessage = null);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 1);
  }

  void _backToStep1() {
    setState(() {
      _errorMessage = null;
      _currentStep = 0;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleSubmit() async {
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _passwordConfirmController.text,
        );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    context.pushReplacement('/check-email', extra: _emailController.text.trim());
  }

  /// 0 (kosong/sangat lemah) s.d. 4 (sangat kuat) — heuristik sederhana,
  /// bukan validasi server. Server tetap sumber kebenaran untuk aturan password.
  int _passwordStrength(String value) {
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$&*~%^(),.?":{}|<>_\-]').hasMatch(value)) score++;
    return score;
  }

  Color _strengthColor(int score) {
    switch (score) {
      case 0:
      case 1:
        return AppColors.danger600;
      case 2:
        return AppColors.gold600;
      case 3:
        return AppColors.success600;
      default:
        return AppColors.success700;
    }
  }

  String _strengthLabel(int score) {
    switch (score) {
      case 0:
        return '';
      case 1:
        return 'Lemah';
      case 2:
        return 'Cukup';
      case 3:
        return 'Kuat';
      default:
        return 'Sangat kuat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
          onPressed: () {
            if (_currentStep == 1) {
              _backToStep1();
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _currentStep == 0 ? 'Data Diri' : 'Buat Password',
          style: const TextStyle(color: AppColors.neutral900, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          _progressSegment(active: true),
          const SizedBox(width: 6),
          _progressSegment(active: _currentStep == 1),
        ],
      ),
    );
  }

  Widget _progressSegment({required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 4,
        decoration: BoxDecoration(
          color: active ? AppColors.brand500 : AppColors.neutral200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Siapa nama kamu?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Isi data diri untuk membuat akun KelasXtra.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(label: 'Nama Lengkap', hint: 'cth. Budi Santoso'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
                if (value.trim().length < 3) return 'Nama minimal 3 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(label: 'Email', hint: 'nama@email.com'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Email wajib diisi';
                final regex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                if (!regex.hasMatch(value.trim())) return 'Format email tidak valid';
                return null;
              },
              onFieldSubmitted: (_) => _goToStep2(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goToStep2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Lanjutkan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    final strength = _passwordStrength(_passwordController.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buat password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.neutral900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gunakan kombinasi huruf, angka, dan simbol.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(label: 'Password', hint: 'Minimal 8 karakter').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.neutral400,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Password wajib diisi';
                if (value.length < 8) return 'Password minimal 8 karakter';
                return null;
              },
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: strength / 4,
                        minHeight: 4,
                        backgroundColor: AppColors.neutral200,
                        valueColor: AlwaysStoppedAnimation(_strengthColor(strength)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _strengthLabel(strength),
                    style: TextStyle(fontSize: 12, color: _strengthColor(strength), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordConfirmController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(label: 'Konfirmasi Password', hint: 'Ulangi password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.neutral400,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Konfirmasi password wajib diisi';
                if (value != _passwordController.text) return 'Password tidak sama';
                return null;
              },
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(_errorMessage!),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Daftar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger100),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required String hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.neutral500, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 13),
      filled: true,
      fillColor: AppColors.neutral50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger600),
      ),
    );
  }
}