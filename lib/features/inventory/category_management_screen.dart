import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category.dart';
import '../../data/repositories/product_repository.dart';
import '../../state/auth_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _categoryRepo = CategoryRepository();

  List<Category> _categories = [];
  bool _loading = true;
  String? _error;
  final Set<String> _togglingIds = {};

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
      final categories =
          await _categoryRepo.getCategories(includeInactive: true);
      if (mounted) setState(() => _categories = categories);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Category category, bool value) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx == -1) return;
    setState(() {
      _togglingIds.add(category.id);
      _categories[idx] = category.copyWith(isActive: value);
    });
    try {
      final updated = await _categoryRepo.setCategoryActive(category.id, value);
      if (!mounted) return;
      setState(() {
        final i = _categories.indexWhere((c) => c.id == category.id);
        if (i != -1) _categories[i] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value
              ? 'Kategori "${category.name}" diaktifkan'
              : 'Kategori "${category.name}" dinonaktifkan')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _categories.indexWhere((c) => c.id == category.id);
        if (i != -1) _categories[i] = category;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _togglingIds.remove(category.id));
    }
  }

  Future<void> _showForm({Category? category}) async {
    final ctrl = TextEditingController(text: category?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama Kategori'),
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Nama kategori minimal 2 karakter'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null) return;

    try {
      if (category == null) {
        await _categoryRepo.createCategory(name);
      } else {
        await _categoryRepo.updateCategory(category.id, name);
      }
      _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Kategori "${category.name}" akan dihapus permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _categoryRepo.deleteCategory(category.id);
      _load();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori / Jasa'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori'),
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (_categories.isEmpty) {
      return const Center(
          child: Text('Belum ada kategori',
              style: TextStyle(color: AppColors.muted)));
    }

    final canManageStatus =
        context.watch<AuthProvider>().currentUser?.canManageCategoryStatus ??
            false;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = _categories[i];
          final isToggling = _togglingIds.contains(c.id);
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Row(
                children: [
                  Expanded(
                    child: Text(c.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: c.isActive ? null : AppColors.muted,
                        )),
                  ),
                  if (!c.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.muted.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Nonaktif',
                          style:
                              TextStyle(fontSize: 11, color: AppColors.muted)),
                    ),
                ],
              ),
              subtitle: Text('${c.productCount} produk',
                  style: const TextStyle(fontSize: 12.5)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canManageStatus)
                    isToggling
                        ? const SizedBox(
                            width: 40,
                            height: 20,
                            child: Center(
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))))
                        : Semantics(
                            label: 'Status aktif kategori ${c.name}',
                            child: Switch(
                              value: c.isActive,
                              onChanged: (v) => _toggleActive(c, v),
                            ),
                          ),
                  IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _showForm(category: c)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.danger),
                    onPressed: () => _confirmDelete(c),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
