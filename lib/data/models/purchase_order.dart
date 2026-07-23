import '../../core/utils/num_parser.dart';
import 'category.dart';
import 'supplier.dart';

class PurchaseOrderItem {
  final String productId;
  final String productName;
  final String unit;
  final int qty;
  final num unitCost;
  final num subtotal;

  PurchaseOrderItem({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.qty,
    required this.unitCost,
    required this.subtotal,
  });

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return PurchaseOrderItem(
      productId: json['productId'] as String,
      productName: product?['name'] as String? ?? '-',
      unit: product?['unit'] as String? ?? 'pcs',
      qty: parseInt(json['qty']),
      unitCost: parseNum(json['unitCost']),
      subtotal: parseNum(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() => {'productId': productId, 'qty': qty, 'unitCost': unitCost};
}

class PurchasePayment {
  final String id;
  final String method; // CASH | TRANSFER (pelunasan tidak pakai CREDIT)
  final num amount;
  final String? referenceNo;
  final DateTime createdAt;

  PurchasePayment({required this.id, required this.method, required this.amount, this.referenceNo, required this.createdAt});

  factory PurchasePayment.fromJson(Map<String, dynamic> json) {
    return PurchasePayment(
      id: json['id'] as String,
      method: json['method'] as String,
      amount: parseNum(json['amount']),
      referenceNo: json['referenceNo'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String status; // DRAFT | RECEIVED | CANCELLED
  final num total;
  final String paymentMethod; // CASH | CREDIT | TRANSFER
  final String paymentStatus; // UNPAID | PARTIAL | PAID
  final num paidAmount;
  final DateTime createdAt;
  final Supplier? supplier;
  final Warehouse? warehouse;
  final List<PurchaseOrderItem> items;
  final List<PurchasePayment> payments;
  final String? businessName;
  final String? businessAddress;
  final String? businessPhone;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.status,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paidAmount,
    required this.createdAt,
    this.supplier,
    this.warehouse,
    required this.items,
    this.payments = const [],
    this.businessName,
    this.businessAddress,
    this.businessPhone,
  });

  /// Sisa hutang yang belum dibayar. Hanya relevan kalau [paymentMethod] == CREDIT.
  num get outstandingDebt {
    final remaining = total - paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  bool get isCreditPurchase => paymentMethod == 'CREDIT';
  bool get isDebtSettled => paymentStatus == 'PAID';

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>?) ?? [];
    final paymentsJson = (json['payments'] as List<dynamic>?) ?? [];
    final tenant = json['tenant'] as Map<String, dynamic>?;
    return PurchaseOrder(
      id: json['id'] as String,
      poNumber: json['poNumber'] as String,
      status: json['status'] as String,
      total: parseNum(json['total']),
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
      paidAmount: parseNum(json['paidAmount']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      supplier: json['supplier'] != null ? Supplier.fromJson(json['supplier'] as Map<String, dynamic>) : null,
      warehouse: json['warehouse'] != null ? Warehouse.fromJson(json['warehouse'] as Map<String, dynamic>) : null,
      items: itemsJson.map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      payments: paymentsJson.map((e) => PurchasePayment.fromJson(e as Map<String, dynamic>)).toList(),
      businessName: tenant?['businessName'] as String?,
      businessAddress: tenant?['address'] as String?,
      businessPhone: tenant?['phone'] as String?,
    );
  }
}
