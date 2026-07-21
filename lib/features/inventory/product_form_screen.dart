import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../common/barcode_scanner_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = mode tambah

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();
  final _warehouseRepo = WarehouseRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _minStockCtrl;
  final _initialStockCtrl = TextEditingController();

  List<Category> _categories = [];
  List<Warehouse> _warehouses = [];
  String? _categoryId;
  String? _warehouseId;
  bool _loadingRefData = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? 'pcs');
    _costPriceCtrl = TextEditingController(text: p != null ? p.costPrice.toString() : '');
    _sellPriceCtrl = TextEditingController(text: p != null ? p.sellPrice.toString() : '');
    _minStockCtrl = TextEditingController(text: p != null ? p.minStock.toString() : '0');
    _categoryId = p?.categoryId;
    _loadRefData();
  }

  Future<void> _loadRefData() async {
    try {
      final results = await Future.wait([_categoryRepo.getCategories(), _warehouseRepo.getWarehouses()]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _warehouses = results[1] as List<Warehouse>;
          if (_warehouses.isNotEmpty) _warehouseId = _warehouses.first.id;
        });
      }
    } catch (_) {
      // biarkan kosong, produk tetap bisa disimpan tanpa kategori
    } finally {
      if (mounted) setState(() => _loadingRefData = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _unitCtrl.dispose();
    _costPriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    _minStockCtrl.dispose();
    _initialStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _productRepo.updateProduct(widget.product!.id, {
          'name': _nameCtrl.text.trim(),
          'categoryId': _categoryId,
          'sku': _skuCtrl.text.trim(),
          'barcode': _barcodeCtrl.text.trim(),
          'unit': _unitCtrl.text.trim(),
          'costPrice': num.parse(_costPriceCtrl.text),
          'sellPrice': num.parse(_sellPriceCtrl.text),
          'minStock': int.parse(_minStockCtrl.text),
        });
      } else {
        await _productRepo.createProduct(
          name: _nameCtrl.text.trim(),
          categoryId: _categoryId,
          sku: _skuCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
          costPrice: num.tryParse(_costPriceCtrl.text) ?? 0,
          sellPrice: num.parse(_sellPriceCtrl.text),
          minStock: int.tryParse(_minStockCtrl.text) ?? 0,
          initialStockWarehouseId: _warehouseId,
          initialStockQty: int.tryParse(_initialStockCtrl.text) ?? 0,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await scanBarcode(context, title: 'Scan Barcode Produk');
    if (code != null && mounted) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _confirmDeactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nonaktifkan Produk?'),
        content: const Text('Produk tidak akan muncul lagi di daftar penjualan, tapi histori transaksi lama tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _productRepo.deactivateProduct(widget.product!.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Produk' : 'Tambah Produk'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              onPressed: _confirmDeactivate,
            ),
        ],
      ),
      body: _loadingRefData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
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
                        decoration: const InputDecoration(labelText: 'Nama Produk'),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Nama produk wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _skuCtrl,
                              decoration: const InputDecoration(labelText: 'SKU (opsional)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _unitCtrl,
                              decoration: const InputDecoration(labelText: 'Satuan (pcs/kg/dll)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _barcodeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Barcode (opsional)',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            tooltip: 'Scan barcode',
                            onPressed: _scanBarcode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _costPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Harga Modal'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _sellPriceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Harga Jual'),
                              validator: (v) => (v == null || num.tryParse(v) == null) ? 'Harga tidak valid' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minStockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stok Minimum (untuk peringatan stok menipis)'),
                      ),
                      if (!_isEdit) ...[
                        const SizedBox(height: 20),
                        const Text('Stok Awal (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _warehouseId,
                          decoration: const InputDecoration(labelText: 'Gudang/Toko'),
                          items: _warehouses
                              .map((w) => DropdownMenuItem(value: w.id, child: Text(w.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _warehouseId = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _initialStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Jumlah Stok Awal'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEdit ? 'Simpan Perubahan' : 'Tambah Produk'),
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
