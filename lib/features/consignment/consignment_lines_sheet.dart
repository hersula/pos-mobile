import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/consignment.dart';
import '../../data/repositories/consignment_repository.dart';

class ConsignmentLinesResult {
  final List<ConsignmentLineInput> lines;
  final String? note;
  ConsignmentLinesResult(this.lines, this.note);
}

class _LineState {
  final ConsignmentItem item;
  bool useBaseUnit;
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  _LineState(this.item) : useBaseUnit = true;

  int get qty => int.tryParse(qtyCtrl.text.trim()) ?? 0;

  /// qty dalam satuan dasar (sama dengan perhitungan backend: qty x conversionQty).
  int get baseQty => useBaseUnit ? qty : qty * item.conversionQty;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// Bottom sheet input baris catat-terjual (settle-sale) atau retur.
/// Mengembalikan [ConsignmentLinesResult] lewat Navigator.pop, atau null bila dibatalkan.
class ConsignmentLinesSheet extends StatefulWidget {
  final ConsignmentOrder order;
  final bool isSettle; // true = catat terjual (ada harga), false = retur

  const ConsignmentLinesSheet({super.key, required this.order, required this.isSettle});

  @override
  State<ConsignmentLinesSheet> createState() => _ConsignmentLinesSheetState();
}

class _ConsignmentLinesSheetState extends State<ConsignmentLinesSheet> {
  late final List<_LineState> _lines;
  final _noteCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines = widget.order.items.where((e) => e.baseQtyRemaining > 0).map(_LineState.new).toList();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final result = <ConsignmentLineInput>[];
    for (final l in _lines) {
      if (l.qtyCtrl.text.trim().isEmpty || l.qty == 0) continue;
      if (l.qty < 0) {
        setState(() => _error = 'Qty ${l.item.productName} tidak valid');
        return;
      }
      if (l.baseQty > l.item.baseQtyRemaining) {
        setState(() => _error = 'Qty ${l.item.productName} melebihi sisa (${l.item.baseQtyRemaining} ${l.item.baseUnit})');
        return;
      }
      num? price;
      final priceText = l.priceCtrl.text.trim();
      if (widget.isSettle && priceText.isNotEmpty) {
        price = num.tryParse(priceText);
        if (price == null || price < 0) {
          setState(() => _error = 'Harga ${l.item.productName} tidak valid');
          return;
        }
      }
      result.add(ConsignmentLineInput(consignmentItemId: l.item.id, qty: l.qty, useBaseUnit: l.useBaseUnit, unitPrice: price));
    }
    if (result.isEmpty) {
      setState(() => _error = 'Isi qty minimal untuk 1 produk');
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.of(context).pop(ConsignmentLinesResult(result, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSettle ? 'Catat Barang Terjual' : 'Retur Barang dari Outlet';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.isSettle
                      ? 'Isi jumlah yang terjual saja. Harga kosong = harga kesepakatan. Akan dibuat penjualan (piutang) atas nama ${widget.order.customerName}.'
                      : 'Isi jumlah yang dikembalikan ke gudang ${widget.order.sourceWarehouseName}.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Tidak ada sisa barang', style: TextStyle(color: AppColors.muted))),
                      ),
                    for (final l in _lines) _buildLine(l),
                    const SizedBox(height: 4),
                    TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _lines.isEmpty ? null : _submit,
                        child: Text(widget.isSettle ? 'Catat Terjual' : 'Retur Barang'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(_LineState l) {
    final it = l.item;
    final hasUnit = it.unitLabel != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(
              'Sisa di outlet: ${it.baseQtyRemaining} ${it.baseUnit}'
              '${hasUnit ? ' (1 ${it.unitLabel} = ${it.conversionQty} ${it.baseUnit})' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (hasUnit) ...[
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, label: Text(it.baseUnit)),
                  ButtonSegment(value: false, label: Text(it.unitLabel!)),
                ],
                selected: {l.useBaseUnit},
                onSelectionChanged: (s) => setState(() => l.useBaseUnit = s.first),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: l.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Qty (${l.useBaseUnit ? it.baseUnit : it.displayUnit})', isDense: true),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                if (widget.isSettle) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: l.priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Harga/${l.useBaseUnit ? it.baseUnit : it.displayUnit} (opsional)',
                        hintText: CurrencyFormatter.format(l.useBaseUnit ? it.basePrice : it.agreedUnitPrice),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
