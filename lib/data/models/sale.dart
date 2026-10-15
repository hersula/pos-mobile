import '../../core/utils/num_parser.dart';

class SaleItem {
  final String productId;
  final String productName;
  final String unit;
  final String? unitLabel; // satuan tambahan yang dipilih saat jual (mis. "Dus"), null = satuan dasar
  final int qty;
  final num unitPrice;
  final num discountAmount;
  final num subtotal;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.unit,
    this.unitLabel,
    required this.qty,
    required this.unitPrice,
    required this.discountAmount,
    required this.subtotal,
  });

  /// Label satuan yang ditampilkan: satuan tambahan kalau dipilih, kalau tidak satuan dasar produk.
  String get displayUnit => unitLabel ?? unit;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return SaleItem(
      productId: json['productId'] as String,
      productName: product?['name'] as String? ?? '-',
      unit: product?['unit'] as String? ?? 'pcs',
      unitLabel: json['unitLabel'] as String?,
      qty: parseInt(json['qty']),
      unitPrice: parseNum(json['unitPrice']),
      discountAmount: parseNum(json['discountAmount']),
      subtotal: parseNum(json['subtotal']),
    );
  }
}

class SalePayment {
  final String method; // CASH, DEBIT, CREDIT, QRIS, TRANSFER, EWALLET
  final num amount;
  final String? referenceNo;

  SalePayment({required this.method, required this.amount, this.referenceNo});

  factory SalePayment.fromJson(Map<String, dynamic> json) {
    return SalePayment(
      method: json['method'] as String,
      amount: parseNum(json['amount']),
      referenceNo: json['referenceNo'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method,
        'amount': amount,
        if (referenceNo != null && referenceNo!.isNotEmpty) 'referenceNo': referenceNo,
      };
}

class Sale {
  final String id;
  final String invoiceNo;
  final num subtotal;
  final String discountType;
  final num discountValue;
  final num discountAmount;
  final num taxPercent;
  final num taxAmount;
  final num grandTotal;
  final num paidTotal;
  final num changeAmount;
  final String status; // PAID, PARTIAL, CANCELLED, REFUNDED
  final String? note;
  final DateTime createdAt;
  final List<SaleItem> items;
  final List<SalePayment> payments;
  final String? cashierName;
  final String? customerName;
  final String? businessName;
  final String? businessAddress;
  final String? businessPhone;

  Sale({
    required this.id,
    required this.invoiceNo,
    required this.subtotal,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.grandTotal,
    required this.paidTotal,
    required this.changeAmount,
    required this.status,
    this.note,
    required this.createdAt,
    required this.items,
    required this.payments,
    this.cashierName,
    this.customerName,
    this.businessName,
    this.businessAddress,
    this.businessPhone,
  });

  num get outstanding => grandTotal - paidTotal > 0 ? grandTotal - paidTotal : 0;

  factory Sale.fromJson(Map<String, dynamic> json) {
    final cashier = json['cashier'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final tenant = json['tenant'] as Map<String, dynamic>?;
    final itemsJson = (json['items'] as List<dynamic>?) ?? [];
    final paymentsJson = (json['payments'] as List<dynamic>?) ?? [];

    return Sale(
      id: json['id'] as String,
      invoiceNo: json['invoiceNo'] as String,
      subtotal: parseNum(json['subtotal']),
      discountType: json['discountType'] as String? ?? 'NOMINAL',
      discountValue: parseNum(json['discountValue']),
      discountAmount: parseNum(json['discountAmount']),
      taxPercent: parseNum(json['taxPercent']),
      taxAmount: parseNum(json['taxAmount']),
      grandTotal: parseNum(json['grandTotal']),
      paidTotal: parseNum(json['paidTotal']),
      changeAmount: parseNum(json['changeAmount']),
      status: json['status'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: itemsJson.map((e) => SaleItem.fromJson(e as Map<String, dynamic>)).toList(),
      payments: paymentsJson.map((e) => SalePayment.fromJson(e as Map<String, dynamic>)).toList(),
      cashierName: cashier?['name'] as String?,
      customerName: customer?['name'] as String?,
      businessName: tenant?['businessName'] as String?,
      businessAddress: tenant?['address'] as String?,
      businessPhone: tenant?['phone'] as String?,
    );
  }
}
