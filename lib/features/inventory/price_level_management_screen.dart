import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/price_level.dart';
import '../../data/repositories/product_repository.dart';

class PriceLevelManagementScreen extends StatefulWidget {
  const PriceLevelManagementScreen({super.key});

  @override
  State<PriceLevelManagementScreen> createState() => _PriceLevelManagementScreenState();
}

class _PriceLevelManagementScreenState extends State<PriceLevelManagementScreen> {
  final _priceLevelRepo = PriceLevelRepository();

  List<PriceLevel> _priceLevels = [];
  bool _loading = true;
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
      final priceLevels = await _priceLevelRepo.getPriceLevels();
      if (mounted) setState(() => _priceLevels = priceLevels);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForm({PriceLevel? priceLevel}) async {
    final ctrl = TextEditingController(text: priceLevel?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(priceLevel == null ? 'Tambah Level Harga' : 'Edit Level Harga'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nama Level (mis. Grosir, Member)'),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Nama level minimal 2 karakter' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null) return;

    try {
      if (priceLevel == null) {
        await _priceLevelRepo.createPriceLevel(name);
      } else {
        await _priceLevelRepo.updatePriceLevel(priceLevel.id, name);
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(PriceLevel priceLevel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Level Harga?'),
        content: Text(
          priceLevel.productCount > 0
              ? 'Level "${priceLevel.name}" akan dihapus permanen, termasuk harga khusus yang sudah diisi di ${priceLevel.productCount} produk.'
              : 'Level "${priceLevel.name}" akan dihapus permanen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _priceLevelRepo.deletePriceLevel(priceLevel.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Level Harga'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Level'),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'Harga "Umum" (default) langsung pakai Harga Jual di form produk. Level di sini cuma utk harga TAMBAHAN (mis. Grosir, Member) yang bisa dipilih kasir saat transaksi.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          if (_priceLevels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada level harga tambahan', style: TextStyle(color: AppColors.muted))),
            )
          else
            ..._priceLevels.map(
              (p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.productCount} produk punya harga khusus', style: const TextStyle(fontSize: 12.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(priceLevel: p)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                        onPressed: () => _confirmDelete(p),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
