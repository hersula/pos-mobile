import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/category.dart';
import '../../data/models/consignment.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../../data/models/product_unit.dart';
import '../../data/repositories/consignment_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../common/barcode_scanner_screen.dart';

class _ItemDraft {
  final String productId;
  final String productName;
  final String baseUnit;
  final String? unitId; // null = satuan dasar
  final String? unitLabel;
  int qty;
  num price;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _ItemDraft({
    required this.productId,
    required this.productName,
    required this.baseUnit,
    this.unitId,
    this.unitLabel,
    this.qty = 1,
    required this.price,
  })  : qtyCtrl = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: price.toString());

  String get displayUnit => unitLabel ?? baseUnit;
  num get subtotal => qty * price;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Buat konsinyasi baru, atau ubah dokumen DRAFT bila [existing] diisi.
class ConsignmentFormScreen extends StatefulWidget {
  final ConsignmentOrder? existing;
  const ConsignmentFormScreen({super.key, this.existing});

  @override
  State<ConsignmentFormScreen> createState() => _ConsignmentFormScreenState();
}

class _ConsignmentFormScreenState extends State<ConsignmentFormScreen> {
  final _repo = ConsignmentRepository();
  final _productRepo = ProductRepository();
  final _warehouseRepo = WarehouseRepository();
  final _customerRepo = CustomerRepository();
  final _noteCtrl = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Customer> _customers = [];
  String? _customerId;
  String? _warehouseId;
  DateTime? _dueDate;
  final List<_ItemDraft> _items = [];

  bool _loadingRefData = true;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _customerId = e.customerId;
      _warehouseId = e.sourceWarehouseId;
      _dueDate = e.dueDate;
      _noteCtrl.text = e.note ?? '';
      for (final it in e.items) {
        _items.add(_ItemDraft(
          productId: it.productId,
          productName: it.productName,
          baseUnit: it.baseUnit,
          unitId: it.productUnitId,
          unitLabel: it.unitLabel,
          qty: it.qtySent,
          price: it.agreedUnitPrice,
        ));
      }
    }
    _loadRefData();
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRefData() async {
    setState(() {
      _loadingRefData = true;
      _error = null;
    });
    try {
      // Gudang asal wajib bertipe STORE (default backend); gudang konsinyasi tidak ditampilkan.
      final results = await Future.wait([_warehouseRepo.getWarehouses(type: 'STORE'), _customerRepo.getCustomers()]);
      if (!mounted) return;
      setState(() {
        _warehouses = results[0] as List<Warehouse>;
        _customers = results[1] as List<Customer>;
        if (_warehouseId == null && _warehouses.isNotEmpty) _warehouseId = _warehouses.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingRefData = false);
    }
  }

  num get _total => _items.fold<num>(0, (sum, e) => sum + e.subtotal);

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama outlet/customer')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      final c = await _customerRepo.createCustomer(name: name, phone: phone);
      if (mounted) {
        setState(() {
          _customers = [..._customers, c];
          _customerId = c.id;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickProduct() async {
    final searchCtrl = TextEditingController();
    List<Product> results = [];
    String? searchError;

    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> search(String q) async {
              try {
                final res = await _productRepo.getProducts(search: q);
                setModalState(() {
                  results = res;
                  searchError = null;
                });
              } on ApiException catch (e) {
                setModalState(() => searchError = e.message);
              }
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
                          tooltip: 'Scan barcode',
                          onPressed: scan,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: searchError != null
                          ? Center(child: Text(searchError!, style: const TextStyle(color: AppColors.danger)))
                          : results.isEmpty
                              ? const Center(child: Text('Ketik atau scan untuk mencari produk', style: TextStyle(color: AppColors.muted)))
                              : ListView.builder(
                                  itemCount: results.length,
                                  itemBuilder: (_, i) => ListTile(
                                    title: Text(results[i].name),
                                    subtitle: Text('Stok: ${results[i].totalStock} ${results[i].unit} · Harga: ${CurrencyFormatter.format(results[i].sellPrice)}'),
                                    onTap: () => Navigator.pop(ctx, results[i]),
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
    searchCtrl.dispose();
    if (picked != null && mounted) _pickUnitAndAddItem(picked);
  }

  // Sentinel baris "satuan dasar" supaya dibedakan dari null (sheet ditutup tanpa memilih).
  static const Object _baseUnitChoice = Object();

  Future<void> _pickUnitAndAddItem(Product product) async {
    if (!product.hasMultipleUnits) {
      _addItem(product, null);
      return;
    }
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Titip per Satuan Apa? — ${product.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ListTile(title: Text(product.unit), onTap: () => Navigator.pop(ctx, _baseUnitChoice)),
            ...product.units.map((u) => ListTile(
                  title: Text(u.name),
                  subtitle: Text('1 ${u.name} = ${u.conversionQty} ${product.unit}'),
                  onTap: () => Navigator.pop(ctx, u),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    _addItem(product, choice == _baseUnitChoice ? null : choice as ProductUnit);
  }

  void _addItem(Product product, ProductUnit? unit) {
    setState(() {
      final existing = _items.where((e) => e.productId == product.id && e.unitId == unit?.id);
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
        existing.first.qtyCtrl.text = existing.first.qty.toString();
      } else {
        _items.add(_ItemDraft(
          productId: product.id,
          productName: product.name,
          baseUnit: product.unit,
          unitId: unit?.id,
          unitLabel: unit?.name,
          price: unit?.sellPrice ?? product.sellPrice,
        ));
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_customerId == null) {
      setState(() => _error = 'Pilih customer/outlet terlebih dahulu');
      return;
    }
    if (_warehouseId == null) {
      setState(() => _error = 'Pilih gudang asal terlebih dahulu');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Tambahkan minimal 1 produk');
      return;
    }
    if (_items.any((e) => e.qty < 1)) {
      setState(() => _error = 'Qty tiap produk minimal 1');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final inputs = _items
        .map((e) => ConsignmentItemInput(productId: e.productId, productUnitId: e.unitId, qty: e.qty, agreedUnitPrice: e.price))
        .toList();
    try {
      final note = _noteCtrl.text.trim();
      if (_isEdit) {
        await _repo.update(widget.existing!.id,
            customerId: _customerId!, sourceWarehouseId: _warehouseId!, dueDate: _dueDate, note: note, items: inputs);
      } else {
        await _repo.create(customerId: _customerId!, sourceWarehouseId: _warehouseId!, dueDate: _dueDate, note: note, items: inputs);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah Konsinyasi' : 'Konsinyasi Baru')),
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
                      child: Row(
                        children: [
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13.5))),
                          if (_warehouses.isEmpty || _customers.isEmpty)
                            TextButton(onPressed: _loadRefData, child: const Text('Muat Ulang')),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _customers.any((c) => c.id == _customerId) ? _customerId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Customer / Outlet'),
                          items: _customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _customerId = v),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Customer baru',
                        onPressed: _addCustomer,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _warehouses.any((w) => w.id == _warehouseId) ? _warehouseId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gudang Asal (toko)'),
                    items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                    onChanged: (v) => setState(() => _warehouseId = v),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDueDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Jatuh Tempo (opsional)',
                        suffixIcon: _dueDate == null
                            ? const Icon(Icons.event_rounded)
                            : IconButton(
                                tooltip: 'Hapus tanggal',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() => _dueDate = null),
                              ),
                      ),
                      child: Text(_dueDate == null ? 'Belum ditentukan' : DateFormatter.short(_dueDate!)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    maxLength: 1000,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Barang Dititipkan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
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
                    ...List.generate(_items.length, _buildItemCard),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(child: Text('Nilai Titipan', style: TextStyle(fontWeight: FontWeight.w700))),
                          Text(CurrencyFormatter.format(_total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dokumen disimpan sebagai Draf. Stok baru berpindah ke outlet setelah dikirim dari halaman detail.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: (_submitting || _loadingRefData) ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Draf Konsinyasi'),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
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
                  child: Text(
                    item.unitLabel != null ? '${item.productName} (${item.unitLabel})' : item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus item',
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Qty (${item.displayUnit})', isDense: true),
                    onChanged: (v) => setState(() => item.qty = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: item.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Harga Kesepakatan/${item.displayUnit}', isDense: true),
                    onChanged: (v) => setState(() => item.price = num.tryParse(v) ?? 0),
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
