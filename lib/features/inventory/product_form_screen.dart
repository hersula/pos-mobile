import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/category.dart';
import '../../data/models/price_level.dart';
import '../../data/models/product.dart';
import '../../data/models/product_unit.dart';
import '../../data/repositories/product_repository.dart';
import '../common/barcode_scanner_screen.dart';
import 'product_image_picker.dart';

/// Baris harga per level (mis. Grosir) di form produk -- satu baris per [PriceLevel]
/// yang ada di tenant, field-nya opsional (kosong = pakai Harga Jual/"Umum").
class _LevelPriceDraft {
  final PriceLevel level;
  final TextEditingController priceCtrl;

  _LevelPriceDraft({required this.level, String price = ''}) : priceCtrl = TextEditingController(text: price);

  void dispose() => priceCtrl.dispose();

  /// null = kosong (tidak diisi, pakai harga Umum). Tidak melempar error validasi
  /// krn tiap baris sifatnya opsional -- kalau user isi angka salah, diabaikan saja.
  Map<String, dynamic>? toJson() {
    final price = num.tryParse(priceCtrl.text.trim());
    if (price == null) return null;
    return {'priceLevelId': level.id, 'sellPrice': price};
  }
}

/// Baris draft "satuan tambahan" (mis. Dus) di form produk — [id] null = satuan
/// baru yang belum pernah disimpan, terisi = satuan existing yang sedang diedit.
class _UnitDraft {
  final String? id;
  final TextEditingController nameCtrl;
  final TextEditingController conversionCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController barcodeCtrl;

  _UnitDraft({this.id, String name = '', String conversionQty = '', String sellPrice = '', String barcode = ''})
      : nameCtrl = TextEditingController(text: name),
        conversionCtrl = TextEditingController(text: conversionQty),
        priceCtrl = TextEditingController(text: sellPrice),
        barcodeCtrl = TextEditingController(text: barcode);

  factory _UnitDraft.fromUnit(ProductUnit u) => _UnitDraft(
        id: u.id,
        name: u.name,
        conversionQty: u.conversionQty.toString(),
        sellPrice: u.sellPrice.toString(),
        barcode: u.barcode ?? '',
      );

  void dispose() {
    nameCtrl.dispose();
    conversionCtrl.dispose();
    priceCtrl.dispose();
    barcodeCtrl.dispose();
  }

  /// null = baris belum valid (ada field wajib yang kosong/salah format)
  Map<String, dynamic>? toJson() {
    final name = nameCtrl.text.trim();
    final conversion = int.tryParse(conversionCtrl.text.trim());
    final price = num.tryParse(priceCtrl.text.trim());
    if (name.isEmpty || conversion == null || conversion <= 0 || price == null || price < 0) return null;
    return {
      if (id != null) 'id': id,
      'name': name,
      'conversionQty': conversion,
      'sellPrice': price,
      if (barcodeCtrl.text.trim().isNotEmpty) 'barcode': barcodeCtrl.text.trim(),
    };
  }
}

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
  final _priceLevelRepo = PriceLevelRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _sellPriceCtrl;
  late final TextEditingController _minStockCtrl;
  final _initialStockCtrl = TextEditingController();
  final List<_UnitDraft> _unitDrafts = [];
  final List<_LevelPriceDraft> _levelPriceDrafts = [];

  List<Category> _categories = [];
  List<Warehouse> _warehouses = [];
  String? _categoryId;
  String? _warehouseId;
  bool _loadingRefData = true;
  bool _saving = false;
  String? _error;

  // --- state gambar produk ---
  File? _pickedImage; // file baru yang dipilih, belum diupload
  String? _imageUrl; // path gambar yang tersimpan di server
  bool _imageRemoved = false; // user menghapus gambar yang sudah ada
  double? _uploadProgress; // null = tidak sedang upload

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
    _imageUrl = p?.imageUrl;
    _unitDrafts.addAll((p?.units ?? []).map((u) => _UnitDraft.fromUnit(u)));
    _loadRefData();
  }

  void _addUnitRow() => setState(() => _unitDrafts.add(_UnitDraft()));

  void _removeUnitRow(int index) {
    setState(() {
      _unitDrafts[index].dispose();
      _unitDrafts.removeAt(index);
    });
  }

  Future<void> _scanUnitBarcode(_UnitDraft draft) async {
    final code = await scanBarcode(context, title: 'Scan Barcode Satuan');
    if (code != null && mounted) setState(() => draft.barcodeCtrl.text = code);
  }

  Widget _buildUnitRow(int index) {
    final draft = _unitDrafts[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Satuan (mis. Dus)', isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                  onPressed: () => _removeUnitRow(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: draft.conversionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: '1 ${draft.nameCtrl.text.trim().isEmpty ? "satuan" : draft.nameCtrl.text.trim()} = berapa ${_unitCtrl.text.trim().isEmpty ? "satuan dasar" : _unitCtrl.text.trim()}?', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: draft.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Harga Jual', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: draft.barcodeCtrl,
              decoration: InputDecoration(
                labelText: 'Barcode (opsional)',
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan barcode',
                  onPressed: () => _scanUnitBarcode(draft),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRefData() async {
    try {
      final results = await Future.wait([
        _categoryRepo.getCategories(),
        _warehouseRepo.getWarehouses(),
        _priceLevelRepo.getPriceLevels(),
      ]);
      if (mounted) {
        setState(() {
          _categories = results[0] as List<Category>;
          _warehouses = results[1] as List<Warehouse>;
          if (_warehouses.isNotEmpty) _warehouseId = _warehouses.first.id;

          final priceLevels = results[2] as List<PriceLevel>;
          final existingPrices = widget.product?.prices ?? [];
          _levelPriceDrafts.addAll(priceLevels.map((level) {
            final existing = existingPrices.where((p) => p.priceLevelId == level.id);
            return _LevelPriceDraft(level: level, price: existing.isNotEmpty ? existing.first.sellPrice.toString() : '');
          }));
        });
      }
    } catch (_) {
      // biarkan kosong, produk tetap bisa disimpan tanpa kategori/level harga
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
    for (final d in _unitDrafts) {
      d.dispose();
    }
    for (final d in _levelPriceDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  /// null kalau semua baris satuan tambahan valid; String = pesan error baris yang bermasalah.
  String? _validateUnitDrafts() {
    for (final d in _unitDrafts) {
      if (d.toJson() == null) {
        final label = d.nameCtrl.text.trim().isEmpty ? 'satuan baru' : d.nameCtrl.text.trim();
        return 'Satuan "$label" belum lengkap (nama, konversi, dan harga jual wajib diisi)';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final unitError = _validateUnitDrafts();
    if (unitError != null) {
      setState(() => _error = unitError);
      return;
    }
    final unitsPayload = _unitDrafts.map((d) => d.toJson()!).toList();
    final pricesPayload = _levelPriceDrafts.map((d) => d.toJson()).whereType<Map<String, dynamic>>().toList();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 1) Upload gambar lebih dulu kalau user memilih file baru.
      //    Kalau upload gagal, produk tidak disimpan supaya tidak ada
      //    produk "setengah jadi" tanpa gambar yang user harapkan.
      String? imageUrlToSave = _imageRemoved ? '' : _imageUrl;
      if (_pickedImage != null) {
        setState(() => _uploadProgress = 0);
        imageUrlToSave = await _productRepo.uploadProductImage(
          _pickedImage!.path,
          onProgress: (sent, total) {
            if (mounted && total > 0) {
              setState(() => _uploadProgress = sent / total);
            }
          },
        );
        if (mounted) setState(() => _uploadProgress = null);
      }

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
          if (imageUrlToSave != null) 'imageUrl': imageUrlToSave,
          'units': unitsPayload,
          'prices': pricesPayload,
        });
      } else {
        await _productRepo.createProduct(
          name: _nameCtrl.text.trim(),
          categoryId: _categoryId,
          sku: _skuCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim(),
          unit: _unitCtrl.text.trim().isEmpty ? 'pcs' : _unitCtrl.text.trim(),
          units: unitsPayload,
          prices: pricesPayload,
          costPrice: num.tryParse(_costPriceCtrl.text) ?? 0,
          sellPrice: num.parse(_sellPriceCtrl.text),
          minStock: int.tryParse(_minStockCtrl.text) ?? 0,
          imageUrl: imageUrlToSave,
          initialStockWarehouseId: _warehouseId,
          initialStockQty: int.tryParse(_initialStockCtrl.text) ?? 0,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadProgress = null;
        });
      }
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
                      ProductImagePicker(
                        pickedFile: _pickedImage,
                        imageUrl: _imageRemoved ? null : _imageUrl,
                        enabled: !_saving,
                        uploadProgress: _uploadProgress,
                        onPicked: (file) => setState(() {
                          _pickedImage = file;
                          _imageRemoved = false;
                        }),
                        onRemoved: () => setState(() {
                          _pickedImage = null;
                          _imageRemoved = true;
                        }),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nama Produk'),
                        validator: (v) => (v == null || v.trim().length < 2) ? 'Nama produk wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
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
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Satuan Tambahan (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          TextButton.icon(
                            onPressed: _addUnitRow,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah'),
                          ),
                        ],
                      ),
                      Text(
                        'Contoh: satuan dasar "Botol", tambahkan "Dus" = 24 Botol dengan harga jual sendiri.',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(_unitDrafts.length, (i) => _buildUnitRow(i)),
                      if (_levelPriceDrafts.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Harga per Level (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const Text(
                          'Kosongkan kalau level itu pakai Harga Jual ("Umum") di atas.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        ..._levelPriceDrafts.map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: d.priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Harga ${d.level.name}', isDense: true),
                            ),
                          ),
                        ),
                      ],
                      if (!_isEdit) ...[
                        const SizedBox(height: 20),
                        const Text('Stok Awal (opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _warehouseId,
                          isExpanded: true,
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
