import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/purchase_order.dart';
import '../../data/repositories/purchase_order_repository.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/purchase_order_receipt_builder.dart';
import '../settings/printer_settings_screen.dart';

const _statusLabels = {
  'DRAFT': 'Menunggu Diterima',
  'RECEIVED': 'Sudah Diterima',
  'CANCELLED': 'Dibatalkan',
};

const _statusColors = {
  'DRAFT': AppColors.pending,
  'RECEIVED': AppColors.accent,
  'CANCELLED': AppColors.danger,
};

const _paymentMethodLabels = {
  'CASH': 'Tunai',
  'CREDIT': 'Tempo',
  'TRANSFER': 'Transfer Bank',
};

const _debtStatusLabels = {
  'UNPAID': 'Belum Dibayar',
  'PARTIAL': 'Dibayar Sebagian',
  'PAID': 'Lunas',
};

const _debtStatusColors = {
  'UNPAID': AppColors.danger,
  'PARTIAL': AppColors.pending,
  'PAID': AppColors.accent,
};

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String purchaseOrderId;
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  final _repo = PurchaseOrderRepository();
  final _printerService = BluetoothPrinterService();
  PurchaseOrder? _po;
  bool _loading = true;
  bool _receiving = false;
  bool _printing = false;
  String? _error;
  bool _changed = false;

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
      final po = await _repo.getPurchaseOrderDetail(widget.purchaseOrderId);
      if (mounted) setState(() => _po = po);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmReceive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terima Barang?'),
        content: Text(
          'Stok untuk ${_po?.items.length ?? 0} produk akan otomatis bertambah di gudang "${_po?.warehouse?.name ?? '-'}", dan harga modal produk ter-update mengikuti harga beli ini. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terima Barang')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _receiving = true);
    try {
      await _repo.receivePurchaseOrder(widget.purchaseOrderId);
      _changed = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang diterima, stok berhasil diperbarui'), backgroundColor: AppColors.accent),
        );
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  Future<void> _showPayDebtDialog() async {
    final po = _po;
    if (po == null) return;

    String method = 'CASH';
    final amountCtrl = TextEditingController(text: po.outstandingDebt.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    String? dialogError;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bayar Hutang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sisa hutang: ${CurrencyFormatter.format(po.outstandingDebt)}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              const SizedBox(height: 14),
              if (dialogError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'CASH', label: Text('Tunai')),
                  ButtonSegment(value: 'TRANSFER', label: Text('Transfer')),
                ],
                selected: {method},
                onSelectionChanged: (s) => setDialogState(() => method = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Jumlah Bayar'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'No. Referensi (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = num.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) {
                        setDialogState(() => dialogError = 'Jumlah bayar tidak valid');
                        return;
                      }
                      if (amount > po.outstandingDebt + 0.01) {
                        setDialogState(() => dialogError = 'Jumlah melebihi sisa hutang');
                        return;
                      }

                      setDialogState(() {
                        submitting = true;
                        dialogError = null;
                      });

                      try {
                        await _repo.payDebt(po.id, method: method, amount: amount, referenceNo: refCtrl.text.trim());
                        _changed = true;
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _load();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pembayaran hutang berhasil dicatat'), backgroundColor: AppColors.accent),
                          );
                        }
                      } on ApiException catch (e) {
                        setDialogState(() {
                          dialogError = e.message;
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Bayar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printNota() async {
    final po = _po;
    if (po == null) return;

    setState(() => _printing = true);
    try {
      String? address = await LocalStorage.instance.getPrinterAddress();
      if (address == null) {
        _showMessage('Belum ada printer terhubung. Atur dulu di menu Pengaturan.', isError: true);
        final connected = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
        );
        if (connected != true) return;
        address = await LocalStorage.instance.getPrinterAddress();
        if (address == null) return;
      }

      final isConnected = await _printerService.isConnected();
      if (!isConnected) {
        final ok = await _printerService.connect(address);
        if (!ok) {
          _showMessage('Gagal terhubung ke printer. Coba sambungkan ulang di Pengaturan.', isError: true);
          return;
        }
      }

      final paperSize = await _getSavedPaperSize();
      final bytes = await PurchaseOrderReceiptBuilder.build(po, paperSize: paperSize);
      final result = await _printerService.printBytes(bytes);

      _showMessage(result.success ? 'Nota berhasil dicetak' : 'Gagal mengirim data ke printer', isError: !result.success);
    } catch (e) {
      _showMessage('Terjadi kesalahan saat mencetak: $e', isError: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<PaperSize> _getSavedPaperSize() async {
    final saved = await LocalStorage.instance.getPrinterPaperSize();
    return saved == 'mm80' ? PaperSize.mm80 : PaperSize.mm58;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.danger : AppColors.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final showReceiveButton = po?.status == 'DRAFT';
    final showPayDebtButton = po != null && po.status == 'RECEIVED' && po.isCreditPurchase && !po.isDebtSettled;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: Text(po?.poNumber ?? 'Detail Pengadaan'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            if (po != null)
              IconButton(
                icon: _printing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print_rounded),
                tooltip: 'Cetak Nota',
                onPressed: _printing ? null : _printNota,
              ),
          ],
        ),
        body: _loading
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
                : po == null
                    ? const SizedBox()
                    : SafeArea(child: _buildContent(po)),
        bottomNavigationBar: po == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _printing ? null : _printNota,
                          icon: _printing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Cetak Nota'),
                        ),
                      ),
                      if (showReceiveButton) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _receiving ? null : _confirmReceive,
                            icon: _receiving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.inventory_rounded, size: 18),
                            label: const Text('Terima Barang'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                          ),
                        ),
                      ] else if (showPayDebtButton) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _showPayDebtDialog,
                            icon: const Icon(Icons.payments_rounded, size: 18),
                            label: Text('Bayar Hutang · ${CurrencyFormatter.format(po.outstandingDebt)}'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pending),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildContent(PurchaseOrder po) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: (_statusColors[po.status] ?? AppColors.muted).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            _statusLabels[po.status] ?? po.status,
            style: TextStyle(fontWeight: FontWeight.w800, color: _statusColors[po.status] ?? AppColors.muted),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow('No. Pengadaan', po.poNumber),
                _infoRow('Tanggal Dibuat', DateFormatter.dateTime(po.createdAt)),
                _infoRow('Supplier', po.supplier?.name ?? 'Tanpa supplier'),
                _infoRow('Gudang/Toko', po.warehouse?.name ?? '-'),
                _infoRow('Metode Pembayaran', _paymentMethodLabels[po.paymentMethod] ?? po.paymentMethod),
              ],
            ),
          ),
        ),
        if (po.status == 'RECEIVED' && po.isCreditPurchase) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status Hutang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_debtStatusColors[po.paymentStatus] ?? AppColors.muted).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _debtStatusLabels[po.paymentStatus] ?? po.paymentStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _debtStatusColors[po.paymentStatus] ?? AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _infoRow('Sudah Dibayar', CurrencyFormatter.format(po.paidAmount)),
                  _infoRow('Sisa Hutang', CurrencyFormatter.format(po.outstandingDebt)),
                  if (po.payments.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Text('Riwayat Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    ...po.payments.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${_paymentMethodLabels[p.method] ?? p.method} · ${DateFormatter.short(p.createdAt)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ),
                              Text(CurrencyFormatter.format(p.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Item Pembelian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 8),
        ...po.items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: Text('${item.qty} ${item.displayUnit} x ${CurrencyFormatter.format(item.unitCost)}', style: const TextStyle(fontSize: 12)),
                trailing: Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            )),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                Text(CurrencyFormatter.format(po.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
              ],
            ),
          ),
        ),
        if (po.status == 'DRAFT')
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Stok belum bertambah sampai barang ini ditandai "Terima Barang".',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5))),
        ],
      ),
    );
  }
}
