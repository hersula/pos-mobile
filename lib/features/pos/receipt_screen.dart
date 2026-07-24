import 'package:flutter/material.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/sale.dart';
import '../../data/repositories/sales_repository.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/receipt_builder.dart';
import '../settings/printer_settings_screen.dart';

const _paymentMethodLabels = {
  'CASH': 'Tunai',
  'DEBIT': 'Kartu Debit',
  'CREDIT': 'Kartu Kredit',
  'QRIS': 'QRIS',
  'TRANSFER': 'Transfer',
  'EWALLET': 'E-Wallet',
};

class ReceiptScreen extends StatefulWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _printerService = BluetoothPrinterService();
  final _salesRepo = SalesRepository();
  bool _printing = false;

  Future<void> _printReceipt() async {
    setState(() => _printing = true);
    try {
      final address = await LocalStorage.instance.getPrinterAddress();
      if (address == null) {
        _showMessage('Belum ada printer terhubung. Atur dulu di menu Pengaturan.', isError: true);
        final connected = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
        );
        if (connected != true) return;
      }

      final printerAddress = await LocalStorage.instance.getPrinterAddress();
      if (printerAddress == null) return;

      var isConnected = await _printerService.isConnected();
      if (!isConnected) {
        // Koneksi Bluetooth SPP tidak bertahan lintas sesi app — walau device
        // sudah paired & pernah dipilih sebelumnya, socket-nya perlu di-connect
        // ulang tiap kali app dibuka lagi. Coba sambungkan otomatis dulu di sini
        // sebelum nyerah, supaya user tidak perlu bolak-balik ke Pengaturan.
        isConnected = await _printerService.connect(printerAddress);
        if (!isConnected) {
          _showMessage('Gagal terhubung ke printer. Coba sambungkan ulang di Pengaturan.', isError: true);
          return;
        }
      }

      // Ambil ulang detail transaksi dari server sebelum cetak — memastikan
      // data toko/kasir/item selalu lengkap & terbaru, apapun sumber objek
      // Sale yang dipakai untuk buka layar ini (mis. langsung dari respons
      // checkout yang mungkin belum lengkap relasinya).
      Sale saleToPrint = widget.sale;
      try {
        saleToPrint = await _salesRepo.getSaleDetail(widget.sale.id);
      } catch (_) {
        // Kalau gagal (mis. offline), tetap lanjut cetak pakai data yang ada
      }

      final paperSize = await _getSavedPaperSize();
      final bytes = await ReceiptBuilder.build(saleToPrint, paperSize: paperSize);
      final success = await _printerService.printBytes(bytes);

      _showMessage(success ? 'Struk berhasil dicetak' : 'Gagal mengirim data ke printer', isError: !success);
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
    final sale = widget.sale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Struk Transaksi'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _StatusBanner(status: sale.status),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(sale.businessName ?? 'Toko', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (sale.businessAddress != null)
                      Text(sale.businessAddress!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                    const SizedBox(height: 10),
                    const _DashedDivider(),
                    const SizedBox(height: 10),
                    _line('No. Struk', sale.invoiceNo),
                    _line('Tanggal', DateFormatter.dateTime(sale.createdAt)),
                    if (sale.cashierName != null) _line('Kasir', sale.cashierName!),
                    if (sale.customerName != null) _line('Pelanggan', sale.customerName!),
                    const SizedBox(height: 10),
                    const _DashedDivider(),
                    const SizedBox(height: 10),
                    ...sale.items.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('${item.qty} x ${CurrencyFormatter.format(item.unitPrice)}',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Text(CurrencyFormatter.format(item.subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    const _DashedDivider(),
                    const SizedBox(height: 10),
                    _amountLine('Subtotal', sale.subtotal),
                    if (sale.discountAmount > 0) _amountLine('Diskon', -sale.discountAmount),
                    if (sale.taxAmount > 0) _amountLine('PPN (${sale.taxPercent}%)', sale.taxAmount),
                    const SizedBox(height: 6),
                    const _DashedDivider(),
                    const SizedBox(height: 6),
                    _amountLine('TOTAL', sale.grandTotal, bold: true),
                    const SizedBox(height: 8),
                    ...sale.payments.map((p) => _amountLine(_paymentMethodLabels[p.method] ?? p.method, p.amount)),
                    if (sale.changeAmount > 0) _amountLine('Kembalian', sale.changeAmount),
                    if (sale.status == 'PARTIAL' && sale.outstanding > 0) ...[
                      const SizedBox(height: 6),
                      const _DashedDivider(),
                      const SizedBox(height: 6),
                      _amountLine('SISA TAGIHAN', sale.outstanding, bold: true, color: AppColors.pending),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Transaksi Baru'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _printReceipt,
                  icon: _printing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak Struk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _amountLine(String label, num amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: bold ? 14 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(fontSize: bold ? 15 : 12.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'PAID': (AppColors.accent, AppColors.accentSoft, 'Lunas', Icons.check_circle_rounded),
      'PARTIAL': (AppColors.pending, AppColors.pendingSoft, 'Belum Lunas', Icons.hourglass_top_rounded),
      'CANCELLED': (AppColors.danger, AppColors.dangerSoft, 'Dibatalkan', Icons.cancel_rounded),
      'REFUNDED': (AppColors.muted, AppColors.paper, 'Refund', Icons.replay_rounded),
    };
    final (color, bg, label, icon) = map[status] ?? (AppColors.muted, AppColors.paper, status, Icons.info_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 6).floor();
          return Row(
            children: List.generate(
              count,
              (_) => const Expanded(child: SizedBox(height: 1, child: DecoratedBox(decoration: BoxDecoration(color: AppColors.line)))),
            ).expand((w) => [w, const SizedBox(width: 3)]).toList(),
          );
        },
      ),
    );
  }
}
