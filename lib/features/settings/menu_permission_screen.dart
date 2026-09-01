import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/role_labels.dart';
import '../../data/models/menu_permission.dart';
import '../../data/repositories/menu_permission_repository.dart';

const _menuLabels = {
  'kasir': 'Kasir',
  'inventori': 'Inventori',
  'laporan': 'Laporan',
  'pengaturan': 'Pengaturan',
};

class MenuPermissionScreen extends StatefulWidget {
  const MenuPermissionScreen({super.key});

  @override
  State<MenuPermissionScreen> createState() => _MenuPermissionScreenState();
}

class _MenuPermissionScreenState extends State<MenuPermissionScreen> {
  final _repo = MenuPermissionRepository();

  List<RoleMenuPermissions> _matrix = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final matrix = await _repo.getPermissions();
      if (mounted) setState(() => _matrix = matrix);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String role, String menuKey, bool value) async {
    setState(() {
      _matrix = _matrix.map((r) {
        if (r.role != role) return r;
        return RoleMenuPermissions(
          role: r.role,
          menus: r.menus.map((m) => m.menuKey == menuKey ? MenuAccessEntry(menuKey: m.menuKey, canAccess: value, locked: m.locked) : m).toList(),
        );
      }).toList();
      _saving = true;
    });

    try {
      final updated = await _repo.updatePermissions([
        {'role': role, 'menuKey': menuKey, 'canAccess': value},
      ]);
      if (mounted) setState(() => _matrix = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        await _load(); // rollback ke state server kalau gagal
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Otoritas Menu'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load)],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Atur menu apa saja yang boleh diakses tiap level. Pemilik (OWNER) selalu punya akses penuh, dan menu Pengaturan tidak bisa dimatikan supaya semua orang tetap bisa logout.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ),
        for (final r in _matrix)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(roleLabels[r.role] ?? r.role, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  for (final m in r.menus)
                    SwitchListTile(
                      dense: true,
                      title: Text(_menuLabels[m.menuKey] ?? m.menuKey),
                      subtitle: m.locked ? const Text('Selalu diizinkan', style: TextStyle(fontSize: 11)) : null,
                      value: m.canAccess,
                      onChanged: (m.locked || _saving) ? null : (v) => _toggle(r.role, m.menuKey, v),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
