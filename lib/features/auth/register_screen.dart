import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/auth_repository.dart';
import 'registration_submitted_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _planType = 'FREE';
  bool _loading = false;
  String? _error;

  final _authRepository = AuthRepository();

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authRepository.registerTenant(
        businessName: _businessNameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        password: _passwordCtrl.text,
        planType: _planType,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RegistrationSubmittedScreen(planType: _planType)),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Toko Baru')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/icon/app_icon.png', width: 56, height: 56),
                  ),
                ),
                const SizedBox(height: 20),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5)),
                  ),
                const Text('Pilih Paket', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Gratis',
                  subtitle: 'Mulai pakai langsung, cocok untuk usaha kecil yang baru mulai. Dibatasi 10 transaksi per hari.',
                  selected: _planType == 'FREE',
                  onTap: () => setState(() => _planType = 'FREE'),
                ),
                const SizedBox(height: 10),
                _PlanCard(
                  title: 'Berlangganan',
                  subtitle: 'Transaksi tanpa batas + trial gratis 30 hari. Setelah trial, cukup ajukan pembayaran untuk lanjut.',
                  selected: _planType == 'SUBSCRIBE',
                  onTap: () => setState(() => _planType = 'SUBSCRIBE'),
                ),
                const SizedBox(height: 24),
                const Text('Data Usaha', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _businessNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Usaha / Toko'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Minimal 3 karakter' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pemilik'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Minimal 3 karakter' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor Telepon'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Alamat Usaha'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Kata Sandi'),
                  validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Daftar Sekarang'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Setelah mendaftar, tim admin kami akan meninjau data usahamu sebelum akun bisa dipakai.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent : AppColors.line, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
