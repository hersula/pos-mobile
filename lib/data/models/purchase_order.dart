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

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String status; // DRAFT | RECEIVED | CANCELLED
  final num total;
  final DateTime createdAt;
  final Supplier? supplier;
  final Warehouse? warehouse;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.status,
    required this.total,
    required this.createdAt,
    this.supplier,
    this.warehouse,
    required this.items,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>?) ?? [];
    return PurchaseOrder(
      id: json['id'] as String,
      poNumber: json['poNumber'] as String,
      status: json['status'] as String,
      total: parseNum(json['total']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      supplier: json['supplier'] != null ? Supplier.fromJson(json['supplier'] as Map<String, dynamic>) : null,
      warehouse: json['warehouse'] != null ? Warehouse.fromJson(json['warehouse'] as Map<String, dynamic>) : null,
      items: itemsJson.map((e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
