import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../data/models/purchase_order.dart';

const _paymentMethodLabels = {
  'CASH': 'Tunai',
  'CREDIT': 'Tempo',
  'TRANSFER': 'Transfer Bank',
};

const _poStatusLabels = {
  'DRAFT': 'Menunggu Diterima',
  'RECEIVED': 'Sudah Diterima',
  'CANCELLED': 'Dibatalkan',
};

const _debtStatusLabels = {
  'UNPAID': 'Belum Dibayar',
  'PARTIAL': 'Dibayar Sebagian',
  'PAID': 'Lunas',
};

/// Menyusun nota pengadaan barang (purchase order) menjadi rangkaian byte
/// ESC/POS siap kirim ke printer thermal Bluetooth. Dipakai sebagai bukti
/// fisik penerimaan barang dari supplier / arsip toko — mencantumkan rincian
/// item, metode pembayaran, dan status hutang kalau pembeliannya tempo.
class PurchaseOrderReceiptBuilder {
  static Future<List<int>> build(PurchaseOrder po, {PaperSize paperSize = PaperSize.mm58}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final bytes = <int>[];

    // Reset printer ke kondisi default dulu (bersihkan sisa state cetak sebelumnya)
    bytes.addAll(generator.reset());

    bytes.addAll(generator.text(
      po.businessName ?? 'Toko',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    if (po.businessAddress != null && po.businessAddress!.isNotEmpty) {
      bytes.addAll(generator.text(po.businessAddress!, styles: const PosStyles(align: PosAlign.center)));
    }
    if (po.businessPhone != null && po.businessPhone!.isNotEmpty) {
      bytes.addAll(generator.text(po.businessPhone!, styles: const PosStyles(align: PosAlign.center)));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'NOTA PENGADAAN BARANG',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.text('No. PO: ${po.poNumber}'));
    bytes.addAll(generator.text('Tanggal: ${DateFormatter.dateTime(po.createdAt)}'));
    bytes.addAll(generator.text('Status: ${_poStatusLabels[po.status] ?? po.status}'));
    if (po.supplier != null) bytes.addAll(generator.text('Supplier: ${po.supplier!.name}'));
    if (po.warehouse != null) bytes.addAll(generator.text('Gudang Tujuan: ${po.warehouse!.name}'));
    bytes.addAll(generator.text('Metode Bayar: ${_paymentMethodLabels[po.paymentMethod] ?? po.paymentMethod}'));

    bytes.addAll(generator.hr());

    for (final item in po.items) {
      bytes.addAll(generator.text(item.productName, styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: '${item.qty} ${item.displayUnit} x ${CurrencyFormatter.formatPlain(item.unitCost)}', width: 8),
        PosColumn(
          text: CurrencyFormatter.formatPlain(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }

    bytes.addAll(generator.hr());
    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 7, styles: const PosStyles(bold: true)),
      PosColumn(
        text: CurrencyFormatter.formatPlain(po.total),
        width: 5,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]));

    // Rincian status hutang, khusus pembelian tempo
    if (po.isCreditPurchase && po.status == 'RECEIVED') {
      bytes.addAll(generator.hr());
      bytes.addAll(generator.text('Status Hutang: ${_debtStatusLabels[po.paymentStatus] ?? po.paymentStatus}', styles: const PosStyles(bold: true)));
      bytes.addAll(generator.row([
        PosColumn(text: 'Sudah Dibayar', width: 7),
        PosColumn(text: CurrencyFormatter.formatPlain(po.paidAmount), width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]));
      if (po.outstandingDebt > 0) {
        bytes.addAll(generator.row([
          PosColumn(text: 'Sisa Hutang', width: 7, styles: const PosStyles(bold: true)),
          PosColumn(
            text: CurrencyFormatter.formatPlain(po.outstandingDebt),
            width: 5,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]));
      }
    }

    if (po.status == 'DRAFT') {
      bytes.addAll(generator.feed(1));
      bytes.addAll(generator.text(
        'Barang belum diterima - stok belum bertambah.',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    // Kolom tanda tangan - lazim dipakai di nota pengadaan fisik sebagai bukti serah terima
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.row([
      PosColumn(text: 'Diserahkan oleh,', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: 'Diterima oleh,', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]));
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.row([
      PosColumn(text: '(.....................)', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: '(.....................)', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}
