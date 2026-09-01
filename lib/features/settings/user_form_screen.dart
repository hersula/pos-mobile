import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/role_labels.dart';
import '../../data/models/app_user.dart';
import '../../data/repositories/user_repository.dart';
import '../../state/auth_provider.dart';

class UserFormScreen extends StatefulWidget {
  final AppUser? user; // null = mode tambah

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userRepo = UserRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  final _passwordCtrl = TextEditingController();

  late String _role;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _role = u?.role ?? 'KASIR';
    _isActive = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isSelf => _isEdit && widget.user!.id == context.read<AuthProvider>().currentUser?.id;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _userRepo.updateUser(widget.user!.id, {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'role': _role,
          'isActive': _isActive,
          if (_passwordCtrl.text.isNotEmpty) 'password': _passwordCtrl.text,
        });
      } else {
        await _userRepo.createUser(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _role,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nonaktifkan User?'),
        content: const Text('User tidak akan bisa login lagi, tapi histori transaksinya tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _userRepo.deactivateUser(widget.user!.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit User' : 'Tambah User'),
        actions: [
          if (_isEdit && !_isSelf)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: _confirmDeactivate,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5)),
                  ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) => (v == null || v.trim().length < 2) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  enabled: !_isEdit, // email tidak bisa diubah setelah dibuat
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'No. HP (opsional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: _isEdit ? 'Password Baru (opsional)' : 'Password'),
                  validator: (v) {
                    if (_isEdit) {
                      return (v != null && v.isNotEmpty && v.length < 6) ? 'Password minimal 6 karakter' : null;
                    }
                    return (v == null || v.length < 6) ? 'Password minimal 6 karakter' : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Level (Role)'),
                  items: roleOrder
                      .map((r) => DropdownMenuItem(value: r, child: Text(roleLabels[r] ?? r)))
                      .toList(),
                  onChanged: _isSelf ? null : (v) => setState(() => _role = v ?? _role),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text('User nonaktif tidak bisa login'),
                    value: _isActive,
                    onChanged: _isSelf ? null : (v) => setState(() => _isActive = v),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah User'),
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
