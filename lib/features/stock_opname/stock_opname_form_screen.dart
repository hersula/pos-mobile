import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/stock_opname_repository.dart';
import 'stock_opname_count_screen.dart';
import 'stock_opname_widgets.dart';

class StockOpnameFormScreen extends StatefulWidget {
  const StockOpnameFormScreen({super.key});

  @override
  State<StockOpnameFormScreen> createState() => _StockOpnameFormScreenState();
}

class _StockOpnameFormScreenState extends State<StockOpnameFormScreen> {
  final _repo = StockOpnameRepository();
  final _categoryRepo = CategoryRepository();
  final _warehouseRepo = WarehouseRepository();
  final _noteCtrl = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Category> _categories = [];
  String? _warehouseId;
  String? _categoryId;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String? _error;
  bool _draftExists = false;
  String? _draftId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _warehouseRepo.getWarehouses(type: 'STORE'),
        _categoryRepo.getCategories()
      ]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0] as List<Warehouse>;
        _categories = results[1] as List<Category>;
        if (_warehouses.length == 1) _warehouseId = _warehouses.first.id;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_warehouseId == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
      _draftExists = false;
      _draftId = null;
    });
    try {
      final created = await _repo.create(
          warehouseId: _warehouseId!,
          categoryId: _categoryId,
          note: _noteCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => StockOpnameCountScreen(opnameId: created.id)));
    } on ApiException catch (e) {
      if (!mounted) return;
      final code = apiErrorCode(e);
      setState(() {
        _submitting = false;
        _draftExists = e.statusCode == 409 && code == 'DRAFT_EXISTS';
        final details = e.data?['details'];
        _draftId = details is Map ? details['opnameId']?.toString() : null;
        _error = switch (code) {
          'NO_PRODUCTS' => 'Tidak ada produk aktif untuk kategori/gudang ini.',
          'CONSIGNMENT_WAREHOUSE' => 'Gudang konsinyasi tidak dapat di-opname.',
          'DRAFT_EXISTS' => 'Sudah ada sesi Draft untuk gudang ini.',
          _ when e.statusCode == 409 =>
            'Permintaan bentrok dengan data lain (${e.message}). Muat ulang lalu coba lagi.',
          _ => e.message,
        };
      });
    }
  }

  /// Cari sesi Draft milik gudang terpilih lalu buka.
  Future<void> _openExistingDraft() async {
    if (_draftId != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => StockOpnameCountScreen(opnameId: _draftId!)));
      return;
    }
    try {
      final page = await _repo.getList(status: 'DRAFT', pageSize: 50);
      final match =
          page.data.where((s) => s.warehouseId == _warehouseId).toList();
      if (!mounted) return;
      if (match.isEmpty) {
        setState(() =>
            _error = 'Sesi Draft tidak ditemukan. Buka dari daftar sesi.');
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => StockOpnameCountScreen(opnameId: match.first.id)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Sesi Opname')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? OpnameErrorView(
                    title: 'Gagal memuat data',
                    message: _loadError,
                    onRetry: _load)
                : CenteredColumn(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const OpnameBanner(
                          kind: BannerKind.info,
                          text:
                              'Stok sistem dicatat (snapshot) saat sesi dibuat. Hitungan fisik dibandingkan dengan snapshot ini.',
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _warehouseId,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Gudang *'),
                          items: [
                            for (final w in _warehouses)
                              DropdownMenuItem(value: w.id, child: Text(w.name))
                          ],
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _warehouseId = v),
                        ),
                        if (_warehouseId == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4, left: 12),
                            child: Text('Pilih gudang',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.danger)),
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _categoryId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Kategori (opsional)'),
                          items: [
                            const DropdownMenuItem<String?>(
                                value: null, child: Text('Semua kategori')),
                            for (final c in _categories)
                              DropdownMenuItem<String?>(
                                  value: c.id, child: Text(c.name)),
                          ],
                          onChanged: _submitting
                              ? null
                              : (v) => setState(() => _categoryId = v),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteCtrl,
                          enabled: !_submitting,
                          maxLength: 200,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Catatan (opsional)'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          OpnameBanner(
                            kind: BannerKind.danger,
                            text: _error!,
                            action: _draftExists
                                ? TextButton(
                                    onPressed: _openExistingDraft,
                                    child: const Text('Buka Sesi Draft'))
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: BottomActionBar(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: (_warehouseId == null || _submitting) ? null : _submit,
              child: Text(_submitting ? 'Membuat...' : 'Buat & Mulai Hitung'),
            ),
          ),
        ],
      ),
    );
  }
}
