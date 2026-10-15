import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../data/models/sale.dart';

const _paymentMethodLabels = {
  'CASH': 'Tunai',
  'DEBIT': 'Kartu Debit',
  'CREDIT': 'Kartu Kredit',
  'QRIS': 'QRIS',
  'TRANSFER': 'Transfer',
  'EWALLET': 'E-Wallet',
};

/// Menyusun struk transaksi menjadi rangkaian byte ESC/POS siap kirim ke
/// printer thermal Bluetooth. Mendukung diskon, PPN, dan rincian tiap metode
/// pembayaran (split payment) — kalau transaksi `PARTIAL`, sisa tagihan juga
/// dicetak supaya pelanggan tahu berapa piutangnya.
class ReceiptBuilder {
  static Future<List<int>> build(Sale sale, {PaperSize paperSize = PaperSize.mm58}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    // Reset printer ke kondisi default dulu (bersihkan sisa state cetak sebelumnya)
    bytes.addAll(generator.reset());

    bytes.addAll(generator.text(
      sale.businessName ?? 'Toko',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    if (sale.businessAddress != null && sale.businessAddress!.isNotEmpty) {
      bytes.addAll(generator.text(sale.businessAddress!, styles: const PosStyles(align: PosAlign.center)));
    }
    if (sale.businessPhone != null && sale.businessPhone!.isNotEmpty) {
      bytes.addAll(generator.text(sale.businessPhone!, styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('No: ${sale.invoiceNo}'));
    bytes.addAll(generator.text(DateFormatter.dateTime(sale.createdAt)));
    if (sale.cashierName != null) bytes.addAll(generator.text('Kasir: ${sale.cashierName}'));
    if (sale.customerName != null) bytes.addAll(generator.text('Pelanggan: ${sale.customerName}'));
    bytes.addAll(generator.hr());

    for (final item in sale.items) {
      bytes.addAll(generator.text(item.productName, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: '${item.qty} ${item.displayUnit} x ${CurrencyFormatter.formatPlain(item.unitPrice)}', width: 8),
        PosColumn(
          text: CurrencyFormatter.formatPlain(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
      if (item.discountAmount > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: '  Diskon item', width: 8, styles: const PosStyles(align: PosAlign.left)),
          PosColumn(
            text: '-${CurrencyFormatter.formatPlain(item.discountAmount)}',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]));
      }
    }

    bytes.addAll(generator.hr());
    bytes.addAll(_totalRow(generator, 'Subtotal', sale.subtotal));
    if (sale.discountAmount > 0) {
      final label = sale.discountType == 'PERCENT' ? 'Diskon (${sale.discountValue}%)' : 'Diskon';
      bytes.addAll(_totalRow(generator, label, -sale.discountAmount));
    }
    if (sale.taxAmount > 0) {
      bytes.addAll(_totalRow(generator, 'PPN (${sale.taxPercent}%)', sale.taxAmount));
    }
    bytes.addAll(generator.hr());
    bytes.addAll(_totalRow(generator, 'TOTAL', sale.grandTotal, bold: true));
    bytes.addAll(generator.hr());

    for (final payment in sale.payments) {
      final label = _paymentMethodLabels[payment.method] ?? payment.method;
      bytes.addAll(_totalRow(generator, label, payment.amount));
    }

    if (sale.changeAmount > 0) {
      bytes.addAll(_totalRow(generator, 'Kembalian', sale.changeAmount));
    }

    if (sale.status == 'PARTIAL' && sale.outstanding > 0) {
      bytes.addAll(generator.hr());
      bytes.addAll(_totalRow(generator, 'SISA TAGIHAN', sale.outstanding, bold: true));
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(generator.text('Terima kasih telah berbelanja', styles: const PosStyles(align: PosAlign.center)));
    if (sale.status == 'PARTIAL') {
      bytes.addAll(generator.text('Mohon simpan struk ini untuk pelunasan', styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static List<int> _totalRow(Generator generator, String label, num amount, {bool bold = false}) {
    return generator.row([
      PosColumn(text: label, width: 7, styles: PosStyles(bold: bold)),
      PosColumn(
        text: CurrencyFormatter.formatPlain(amount),
        width: 5,
        styles: PosStyles(align: PosAlign.right, bold: bold),
      ),
    ]);
  }
}
