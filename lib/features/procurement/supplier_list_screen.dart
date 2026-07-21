import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/supplier.dart';
import '../../data/repositories/supplier_repository.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _repo = SupplierRepository();
  List<Supplier> _suppliers = [];
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
      final list = await _repo.getSuppliers();
      if (mounted) setState(() => _suppliers = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String? error;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Supplier Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Supplier')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telepon')),
              const SizedBox(height: 10),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().length < 2) {
                  setDialogState(() => error = 'Nama supplier wajib diisi');
                  return;
                }
                try {
                  await _repo.createSupplier(name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), address: addressCtrl.text.trim());
                  if (context.mounted) Navigator.pop(ctx, true);
                } on ApiException catch (e) {
                  setDialogState(() => error = e.message);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Supplier'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
                      ],
                    ),
                  )
                : _suppliers.isEmpty
                    ? const Center(child: Text('Belum ada supplier', style: TextStyle(color: AppColors.muted)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                          itemCount: _suppliers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final s = _suppliers[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                leading: const Icon(Icons.local_shipping_outlined, color: AppColors.muted),
                                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(s.phone ?? s.address ?? '-', style: const TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
