import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/consignment.dart';
import '../../data/repositories/consignment_repository.dart';
import '../../state/auth_provider.dart';
import 'consignment_form_screen.dart';
import 'consignment_lines_sheet.dart';
import 'consignment_receivables.dart';
import 'consignment_list_screen.dart' show kConsignmentStatusColors;

class ConsignmentDetailScreen extends StatefulWidget {
  final String consignmentId;
  const ConsignmentDetailScreen({super.key, required this.consignmentId});

  @override
  State<ConsignmentDetailScreen> createState() => _ConsignmentDetailScreenState();
}

class _ConsignmentDetailScreenState extends State<ConsignmentDetailScreen> {
  final _repo = ConsignmentRepository();
  ConsignmentOrder? _order;
  bool _loading = true;
  bool _busy = false;
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
      final o = await _repo.getDetail(widget.consignmentId);
      if (mounted) setState(() => _order = o);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppColors.danger : AppColors.accent),
    );
  }

  /// Jalankan aksi tulis; hasilnya (dokumen terbaru) menggantikan state.
  Future<void> _run(Future<ConsignmentOrder> Function() action, String successMsg) async {
    setState(() => _busy = true);
    try {
      final o = await action();
      if (mounted) {
        setState(() => _order = o);
        _toast(successMsg);
      }
    } on ApiException catch (e) {
      if (mounted) {
        _toast(e.message, error: true);
        // Status mungkin sudah berubah di server (409) -> segarkan.
        if (e.statusCode == 409) _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final o = _order!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim Barang?'),
        content: Text(
          'Stok ${o.items.length} produk akan dipindahkan dari gudang "${o.sourceWarehouseName}" ke outlet ${o.customerName}. Dokumen tidak bisa diubah lagi setelah dikirim.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.send(o.id), 'Barang konsinyasi dikirim');
  }

  Future<void> _settle() async {
    final res = await _showLines(true);
    if (res == null) return;
    setState(() => _busy = true);
    try {
      final r = await _repo.settleSale(_order!.id, lines: res.lines, note: res.note);
      if (mounted) {
        setState(() => _order = r.consignment);
        _toast('Penjualan dicatat${r.invoiceNo != null ? ' (${r.invoiceNo})' : ''}');
      }
    } on ApiException catch (e) {
      if (mounted) {
        final freeLimit = e.statusCode == 403 && (e.data?['code'] == 'FREE_LIMIT_REACHED');
        _toast(freeLimit ? 'Kuota transaksi paket FREE hari ini habis. ${e.message}' : e.message, error: true);
        if (e.statusCode == 409) _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _return() async {
    final res = await _showLines(false);
    if (res == null) return;
    await _run(() => _repo.returnItems(_order!.id, lines: res.lines, note: res.note), 'Retur konsinyasi dicatat');
  }

  Future<ConsignmentLinesResult?> _showLines(bool isSettle) {
    return showModalBottomSheet<ConsignmentLinesResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConsignmentLinesSheet(order: _order!, isSettle: isSettle),
    );
  }

  Future<void> _cancel() async {
    final ctrl = TextEditingController();
    String? err;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Batalkan Konsinyasi?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_order?.status == 'SENT')
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('Seluruh stok akan dikembalikan ke gudang asal.', style: TextStyle(fontSize: 13)),
                ),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Alasan (min. 3 karakter)', errorText: err),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kembali')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () {
                if (ctrl.text.trim().length < 3) {
                  setD(() => err = 'Alasan minimal 3 karakter');
                  return;
                }
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: const Text('Batalkan'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (reason == null) return;
    await _run(() => _repo.cancel(_order!.id, reason: reason), 'Konsinyasi dibatalkan');
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConsignmentFormScreen(existing: _order)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = context.watch<AuthProvider>().currentUser?.canWriteConsignment ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(_order?.consignmentNo ?? 'Detail Konsinyasi')),
      body: SafeArea(child: _buildBody(canWrite)),
    );
  }

  Widget _buildBody(bool canWrite) {
    if (_loading && _order == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _order == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    final o = _order!;
    final color = kConsignmentStatusColors[o.status] ?? AppColors.muted;
    final itemName = {for (final i in o.items) i.id: i};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(o.statusLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _kv('Gudang asal', o.sourceWarehouseName),
                  if (o.customerPhone != null && o.customerPhone!.isNotEmpty) _kv('Telepon', o.customerPhone!),
                  if (o.sentAt != null) _kv('Dikirim', DateFormatter.dateTime(o.sentAt!)),
                  if (o.dueDate != null) _kv('Jatuh tempo', DateFormatter.short(o.dueDate!)),
                  if (o.note != null && o.note!.isNotEmpty) _kv('Catatan', o.note!),
                  if (o.cancelReason != null && o.cancelReason!.isNotEmpty) _kv('Alasan batal', o.cancelReason!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _kv('Nilai dikirim', CurrencyFormatter.format(o.summary.totalValueSent)),
                  _kv('Terjual', CurrencyFormatter.format(o.summary.totalValueSold)),
                  _kv('Diretur', CurrencyFormatter.format(o.summary.totalValueReturned)),
                  _kv('Sisa di outlet', CurrencyFormatter.format(o.summary.totalValueRemaining), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Barang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 8),
          if (o.items.isEmpty)
            const Text('Tidak ada item', style: TextStyle(color: AppColors.muted))
          else
            ...o.items.map(_itemCard),
          if (o.settlements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Riwayat Penjualan & Retur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 8),
            ...o.settlements.map((s) => _settlementCard(s, itemName)),
          ],
          ConsignmentReceivables(order: o, canWrite: canWrite, onPaid: _load),
          if (canWrite) ...[
            const SizedBox(height: 20),
            ..._actions(o),
          ] else ...[
            const SizedBox(height: 16),
            const Text('Anda hanya dapat melihat data konsinyasi.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions(ConsignmentOrder o) {
    Widget spinner() => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
    final widgets = <Widget>[];
    if (o.status == 'DRAFT') {
      widgets.add(ElevatedButton.icon(
        onPressed: _busy ? null : _send,
        icon: _busy ? spinner() : const Icon(Icons.local_shipping_outlined),
        label: const Text('Kirim Barang'),
      ));
      widgets.add(const SizedBox(height: 8));
      widgets.add(OutlinedButton.icon(onPressed: _busy ? null : _edit, icon: const Icon(Icons.edit_outlined), label: const Text('Ubah Draf')));
    }
    if (o.canSettleOrReturn) {
      widgets.add(ElevatedButton.icon(
        onPressed: _busy ? null : _settle,
        icon: _busy ? spinner() : const Icon(Icons.point_of_sale_rounded),
        label: const Text('Catat Terjual'),
      ));
      widgets.add(const SizedBox(height: 8));
      widgets.add(OutlinedButton.icon(onPressed: _busy ? null : _return, icon: const Icon(Icons.assignment_return_outlined), label: const Text('Retur Barang')));
    }
    if (o.canCancel) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(OutlinedButton.icon(
        onPressed: _busy ? null : _cancel,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Batalkan Konsinyasi'),
      ));
    } else if (o.status == 'PARTIALLY_SETTLED' || o.status == 'SENT') {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const Text(
        'Tidak bisa dibatalkan karena sudah ada barang terjual/diretur. Gunakan retur, atau batalkan penjualan (Sale) terkait.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ));
    }
    return widgets;
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
          Expanded(child: Text(v, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _itemCard(ConsignmentItem it) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(it.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              'Dikirim: ${it.qtySent} ${it.displayUnit}'
              '${it.unitLabel != null ? ' (= ${it.baseQtySent} ${it.baseUnit})' : ''}'
              ' · ${CurrencyFormatter.format(it.agreedUnitPrice)}/${it.displayUnit}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 14,
              children: [
                Text('Terjual: ${it.baseQtySold} ${it.baseUnit}', style: const TextStyle(fontSize: 12.5)),
                Text('Retur: ${it.baseQtyReturned} ${it.baseUnit}', style: const TextStyle(fontSize: 12.5)),
                Text('Sisa: ${it.baseQtyRemaining} ${it.baseUnit}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _settlementCard(ConsignmentSettlement s, Map<String, ConsignmentItem> items) {
    final isSale = s.type == 'SALE';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isSale ? Icons.point_of_sale_rounded : Icons.assignment_return_outlined, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSale ? 'Terjual${s.invoiceNo != null ? ' · ${s.invoiceNo}' : ''}' : 'Retur',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (s.createdAt != null) Text(DateFormatter.short(s.createdAt!), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
            if (s.isVoided)
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text('Dibatalkan (penjualan dibatalkan)', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 4),
            for (final l in s.lines)
              Text(
                '${items[l.consignmentItemId]?.productName ?? 'Item'}: ${l.baseQty} ${items[l.consignmentItemId]?.baseUnit ?? ''}',
                style: TextStyle(
                  fontSize: 12.5,
                  decoration: s.isVoided ? TextDecoration.lineThrough : null,
                  color: s.isVoided ? AppColors.muted : AppColors.text,
                ),
              ),
            if (s.note != null && s.note!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 3), child: Text(s.note!, style: const TextStyle(color: AppColors.muted, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
