import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/consignment.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';

/// Metode bayar sesuai enum kontrak API (`POST /sales/{id}/payments`).
const kSalePaymentMethods = {
  'CASH': 'Tunai',
  'DEBIT': 'Kartu Debit',
  'CREDIT': 'Kartu Kredit',
  'QRIS': 'QRIS',
  'TRANSFER': 'Transfer Bank',
  'EWALLET': 'E-Wallet',
};

/// Validasi nominal pembayaran piutang. Mengembalikan pesan error, atau null bila valid.
String? validatePaymentAmount(String input, num outstanding) {
  final cleaned = input.trim().replaceAll(',', '.');
  final v = num.tryParse(cleaned);
  if (v == null || v <= 0) return 'Nominal harus lebih dari 0';
  if (v > outstanding) return 'Melebihi sisa piutang (${CurrencyFormatter.format(outstanding)})';
  return null;
}

/// Pesan error pembayaran; 409 CONCURRENT_UPDATE diberi petunjuk coba lagi.
String paymentErrorMessage(ApiException e) {
  if (e.statusCode == 409 && e.data?['code'] == 'CONCURRENT_UPDATE') {
    return 'Terjadi konflik pembayaran paralel, silakan coba lagi.';
  }
  return e.message;
}

/// Daftar penjualan hasil settle (non-void) beserta sisa piutang, dengan aksi "Catat Pembayaran".
class ConsignmentReceivables extends StatefulWidget {
  final ConsignmentOrder order;
  final bool canWrite;

  /// Dipanggil setelah pembayaran sukses agar induk menyegarkan data.
  final VoidCallback? onPaid;

  const ConsignmentReceivables({super.key, required this.order, required this.canWrite, this.onPaid});

  @override
  State<ConsignmentReceivables> createState() => _ConsignmentReceivablesState();
}

class _ConsignmentReceivablesState extends State<ConsignmentReceivables> {
  final _repo = SalesRepository();
  List<Sale> _sales = [];
  bool _loading = true;
  String? _error;

  List<String> get _saleIds => [
        for (final s in widget.order.settlements)
          if (s.type == 'SALE' && !s.isVoided && s.saleId != null) s.saleId!,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConsignmentReceivables old) {
    super.didUpdateWidget(old);
    final oldIds = [
      for (final s in old.order.settlements)
        if (s.type == 'SALE' && !s.isVoided && s.saleId != null) s.saleId!,
    ];
    if (oldIds.join(',') != _saleIds.join(',')) _load();
  }

  Future<void> _load() async {
    final ids = _saleIds;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sales = await Future.wait(ids.map(_repo.getSaleDetail));
      if (mounted) setState(() => _sales = sales);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay(Sale sale) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _PaymentDialog(sale: sale, repo: _repo),
    );
    if (done == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran dicatat'), backgroundColor: AppColors.accent),
      );
      await _load();
      widget.onPaid?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_saleIds.isEmpty) return const SizedBox.shrink();
    final totalOutstanding = _sales.where((s) => s.status == 'PARTIAL').fold<num>(0, (a, s) => a + s.outstanding);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Piutang Penjualan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
            if (!_loading && _error == null)
              Text('Sisa ${CurrencyFormatter.format(totalOutstanding)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Row(
            children: [
              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5))),
              TextButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          )
        else
          ..._sales.map(_saleCard),
      ],
    );
  }

  Widget _saleCard(Sale s) {
    final isPartial = s.status == 'PARTIAL';
    final paid = s.status == 'PAID';
    final color = paid ? AppColors.accent : (isPartial ? AppColors.danger : AppColors.muted);
    final label = paid ? 'Lunas' : (isPartial ? 'Belum Lunas' : s.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _row('Total', CurrencyFormatter.format(s.grandTotal)),
            _row('Dibayar', CurrencyFormatter.format(s.paidTotal)),
            _row('Sisa piutang', CurrencyFormatter.format(s.outstanding), bold: true),
            if (widget.canWrite && isPartial)
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _pay(s),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Catat Pembayaran'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
            Text(v, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}

class _PaymentDialog extends StatefulWidget {
  final Sale sale;
  final SalesRepository repo;
  const _PaymentDialog({required this.sale, required this.repo});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _method = 'CASH';
  String? _amountError;
  String? _serverError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.sale.outstanding;
    _amountCtrl.text = o == o.roundToDouble() ? o.toStringAsFixed(0) : o.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final err = validatePaymentAmount(_amountCtrl.text, widget.sale.outstanding);
    setState(() {
      _amountError = err;
      _serverError = null;
    });
    if (err != null) return;
    setState(() => _saving = true);
    try {
      await widget.repo.addPayment(
        widget.sale.id,
        SalePayment(
          method: _method,
          amount: num.parse(_amountCtrl.text.trim().replaceAll(',', '.')),
          referenceNo: _refCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _serverError = paymentErrorMessage(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return AlertDialog(
      title: const Text('Catat Pembayaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.invoiceNo} · Sisa ${CurrencyFormatter.format(s.outstanding)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Nominal', prefixText: 'Rp ', errorText: _amountError),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Metode bayar'),
              items: kSalePaymentMethods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: _saving ? null : (v) => setState(() => _method = v ?? 'CASH'),
            ),
            if (_method != 'CASH') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _refCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'No. referensi (opsional)'),
              ),
            ],
            if (_serverError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_serverError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_serverError != null ? 'Coba Lagi' : 'Simpan'),
        ),
      ],
    );
  }
}
