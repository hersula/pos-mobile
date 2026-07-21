import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase_order.dart';
import '../../data/models/supplier.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/purchase_order_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../common/barcode_scanner_screen.dart';

class _POItemDraft {
  final Product product;
  int qty;
  num unitCost;
  _POItemDraft({required this.product, this.qty = 1, num? unitCost}) : unitCost = unitCost ?? product.costPrice;

  num get subtotal => qty * unitCost;
}

class PurchaseOrderFormScreen extends StatefulWidget {
  const PurchaseOrderFormScreen({super.key});

  @override
  State<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _productRepo = ProductRepository();
  final _warehouseRepo = WarehouseRepository();
  final _supplierRepo = SupplierRepository();
  final _poRepo = PurchaseOrderRepository();

  List<Warehouse> _warehouses = [];
  List<Supplier> _suppliers = [];
  String? _warehouseId;
  String? _supplierId;
  final List<_POItemDraft> _items = [];

  bool _loadingRefData = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRefData();
  }

  Future<void> _loadRefData() async {
    try {
      final results = await Future.wait([_warehouseRepo.getWarehouses(), _supplierRepo.getSuppliers()]);
      if (mounted) {
        setState(() {
          _warehouses = results[0] as List<Warehouse>;
          _suppliers = results[1] as List<Supplier>;
          if (_warehouses.isNotEmpty) _warehouseId = _warehouses.first.id;
        });
      }
    } catch (_) {
      // suplier boleh kosong; gudang wajib -> divalidasi saat submit
    } finally {
      if (mounted) setState(() => _loadingRefData = false);
    }
  }

  num get _total => _items.fold<num>(0, (sum, e) => sum + e.subtotal);

  Future<void> _pickProduct() async {
    final searchCtrl = TextEditingController();
    List<Product> results = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> search(String q) async {
              final res = await _productRepo.getProducts(search: q);
              setModalState(() => results = res);
            }

            Future<void> scan() async {
              final code = await scanBarcode(ctx, title: 'Scan Barcode Produk');
              if (code != null) {
                searchCtrl.text = code;
                await search(code);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: SizedBox(
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Pilih Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(hintText: 'Cari nama/SKU produk'),
                            onChanged: search,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: scan,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text('Ketik atau scan untuk mencari produk', style: TextStyle(color: AppColors.muted)))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) => ListTile(
                                title: Text(results[i].name),
                                subtitle: Text('Stok: ${results[i].totalStock} ${results[i].unit} · Modal: ${CurrencyFormatter.format(results[i].costPrice)}'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _addItem(results[i]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addItem(Product product) {
    setState(() {
      final existing = _items.where((e) => e.product.id == product.id);
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _items.add(_POItemDraft(product: product));
      }
    });
  }

  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _submit() async {
    if (_warehouseId == null) {
      setState(() => _error = 'Pilih gudang/toko tujuan terlebih dahulu');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Tambahkan minimal 1 produk');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _poRepo.createPurchaseOrder(
        supplierId: _supplierId,
        warehouseId: _warehouseId!,
        items: _items
            .map((e) => PurchaseOrderItem(
                  productId: e.product.id,
                  productName: e.product.name,
                  unit: e.product.unit,
                  qty: e.qty,
                  unitCost: e.unitCost,
                  subtotal: e.subtotal,
                ))
            .toList(),
      );

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengadaan Barang Baru')),
      body: _loadingRefData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5)),
                    ),
                  DropdownButtonFormField<String>(
                    value: _warehouseId,
                    decoration: const InputDecoration(labelText: 'Gudang/Toko Tujuan'),
                    items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _supplierId,
                    decoration: const InputDecoration(labelText: 'Supplier (opsional)'),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Pembelian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      TextButton.icon(
                        onPressed: _pickProduct,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah Produk'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                      child: const Text('Belum ada produk ditambahkan', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    ...List.generate(_items.length, (i) => _buildItemCard(i)),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembelian', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(CurrencyFormatter.format(_total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Simpan Pengadaan Barang'),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final qtyCtrl = TextEditingController(text: item.qty.toString());
    final costCtrl = TextEditingController(text: item.unitCost.toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Qty (${item.product.unit})', isDense: true),
                    onChanged: (v) => setState(() => item.qty = int.tryParse(v) ?? item.qty),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Harga Beli/Satuan', isDense: true),
                    onChanged: (v) => setState(() => item.unitCost = num.tryParse(v) ?? item.unitCost),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Subtotal: ${CurrencyFormatter.format(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}
