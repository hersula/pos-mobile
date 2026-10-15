import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/category.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/sales_repository.dart';
import '../../state/cart_provider.dart';
import 'receipt_screen.dart';

const _paymentMethods = {
  'CASH': 'Tunai',
  'DEBIT': 'Kartu Debit',
  'CREDIT': 'Kartu Kredit',
  'QRIS': 'QRIS',
  'TRANSFER': 'Transfer Bank',
  'EWALLET': 'E-Wallet',
};

class _PaymentEntry {
  String method;
  final TextEditingController amountCtrl;
  final TextEditingController refCtrl;
  _PaymentEntry({this.method = 'CASH', String amount = ''})
      : amountCtrl = TextEditingController(text: amount),
        refCtrl = TextEditingController();
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _warehouseRepo = WarehouseRepository();
  final _salesRepo = SalesRepository();

  List<Warehouse> _warehouses = [];
  String? _warehouseId;
  bool _loadingWarehouses = true;
  bool _submitting = false;
  String? _error;

  final List<_PaymentEntry> _payments = [];

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartProvider>();
    // Default: asumsikan dibayar penuh tunai, kasir tinggal ubah kalau mau split/metode lain
    _payments.add(_PaymentEntry(amount: cart.grandTotal > 0 ? cart.grandTotal.toStringAsFixed(0) : ''));
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final list = await _warehouseRepo.getWarehouses();
      if (mounted) {
        setState(() {
          _warehouses = list;
          if (list.isNotEmpty) _warehouseId = list.first.id;
        });
      }
    } catch (_) {
      // dibiarkan kosong; validasi submit akan menangkap warehouseId null
    } finally {
      if (mounted) setState(() => _loadingWarehouses = false);
    }
  }

  num get _totalPaid => _payments.fold<num>(0, (sum, p) => sum + (num.tryParse(p.amountCtrl.text) ?? 0));

  void _addPaymentRow() {
    final cart = context.read<CartProvider>();
    final remaining = cart.grandTotal - _totalPaid;
    setState(() {
      _payments.add(_PaymentEntry(amount: remaining > 0 ? remaining.toStringAsFixed(0) : ''));
    });
  }

  void _removePaymentRow(int index) {
    setState(() => _payments.removeAt(index));
  }

  Future<void> _submit() async {
    final cart = context.read<CartProvider>();

    if (_warehouseId == null) {
      setState(() => _error = 'Pilih gudang/toko terlebih dahulu');
      return;
    }

    final validPayments = _payments.where((p) => (num.tryParse(p.amountCtrl.text) ?? 0) > 0).toList();
    if (validPayments.isEmpty) {
      setState(() => _error = 'Minimal isi 1 metode pembayaran');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final sale = await _salesRepo.createSale(
        warehouseId: _warehouseId!,
        customerId: cart.selectedCustomer?.id,
        items: cart.items,
        discountType: cart.discountType,
        discountValue: cart.discountValue,
        taxPercent: cart.useTax ? cart.taxPercent : 0,
        note: cart.note,
        payments: validPayments
            .map((p) => SalePayment(
                  method: p.method,
                  amount: num.parse(p.amountCtrl.text),
                  referenceNo: p.refCtrl.text.trim().isEmpty ? null : p.refCtrl.text.trim(),
                ))
            .toList(),
      );

      cart.clear();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ReceiptScreen(sale: sale)),
          (route) => route.isFirst,
        );
      }
    } on ApiException catch (e) {
      if (e.data?['code'] == 'FREE_LIMIT_REACHED') {
        setState(() => _submitting = false);
        _showFreeLimitDialog(e.message);
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showFreeLimitDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batas Transaksi Harian Tercapai'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Nanti Saja')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buka tab "Pengaturan" untuk upgrade ke Berlangganan')),
              );
            },
            child: const Text('Lihat Opsi Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final remaining = cart.grandTotal - _totalPaid;
    final change = remaining < 0 ? -remaining : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: _loadingWarehouses
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Tagihan', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(cart.grandTotal),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_warehouses.length > 1) ...[
                    DropdownButtonFormField<String>(
                      value: _warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Gudang/Toko'),
                      items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (v) => setState(() => _warehouseId = v),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      TextButton.icon(
                        onPressed: _addPaymentRow,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Split Bayar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_payments.length, (i) => _buildPaymentRow(i)),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _row('Total Dibayar', _totalPaid),
                          const SizedBox(height: 6),
                          if (remaining > 0)
                            _row('Sisa Belum Dibayar', remaining, color: AppColors.pending)
                          else
                            _row('Kembalian', change, color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
                  if (remaining > 0)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Transaksi tetap bisa disimpan sebagai piutang (belum lunas) dan dilunasi nanti.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ember),
            child: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(remaining > 0 ? 'Simpan sebagai Piutang' : 'Selesaikan Transaksi'),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRow(int index) {
    final entry = _payments[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: entry.method,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Metode'),
                    items: _paymentMethods.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        entry.method = v ?? 'CASH';
                        // Kalau nominal belum diisi kasir, otomatis isi dengan sisa tagihan
                        if (entry.amountCtrl.text.trim().isEmpty) {
                          final cart = context.read<CartProvider>();
                          final remaining = cart.grandTotal - _totalPaid;
                          if (remaining > 0) entry.amountCtrl.text = remaining.toStringAsFixed(0);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: entry.amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Jumlah'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_payments.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                    onPressed: () => _removePaymentRow(index),
                  ),
              ],
            ),
            if (entry.method != 'CASH') ...[
              const SizedBox(height: 8),
              TextField(
                controller: entry.refCtrl,
                decoration: const InputDecoration(labelText: 'No. Referensi (opsional)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, num amount, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13.5)),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color ?? AppColors.ink),
        ),
      ],
    );
  }
}
