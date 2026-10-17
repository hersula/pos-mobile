import '../../core/utils/num_parser.dart';

const kConsignmentStatusLabels = {
  'DRAFT': 'Draf',
  'SENT': 'Terkirim',
  'PARTIALLY_SETTLED': 'Sebagian Selesai',
  'SETTLED': 'Selesai',
  'CANCELLED': 'Dibatalkan',
};

DateTime? _parseDate(dynamic v) => v is String ? DateTime.tryParse(v) : null;

class ConsignmentSummary {
  final int itemCount;
  final num totalValueSent;
  final num totalValueSold;
  final num totalValueReturned;
  final num totalValueRemaining;

  ConsignmentSummary({
    required this.itemCount,
    required this.totalValueSent,
    required this.totalValueSold,
    required this.totalValueReturned,
    required this.totalValueRemaining,
  });

  factory ConsignmentSummary.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    return ConsignmentSummary(
      itemCount: parseInt(j['itemCount']),
      totalValueSent: parseNum(j['totalValueSent']),
      totalValueSold: parseNum(j['totalValueSold']),
      totalValueReturned: parseNum(j['totalValueReturned']),
      totalValueRemaining: parseNum(j['totalValueRemaining']),
    );
  }
}

class ConsignmentItem {
  final String id;
  final String productId;
  final String productName;
  final String? sku;
  final String baseUnit; // product.unit
  final String? productUnitId;
  final String? unitLabel; // null = satuan dasar
  final int conversionQty;
  final int qtySent;
  final int baseQtySent;
  final int baseQtySold;
  final int baseQtyReturned;
  final int baseQtyRemaining;
  final num agreedUnitPrice; // per satuan terpilih

  ConsignmentItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.sku,
    required this.baseUnit,
    this.productUnitId,
    this.unitLabel,
    required this.conversionQty,
    required this.qtySent,
    required this.baseQtySent,
    required this.baseQtySold,
    required this.baseQtyReturned,
    required this.baseQtyRemaining,
    required this.agreedUnitPrice,
  });

  /// Nama satuan terpilih (mis. Dus) atau satuan dasar.
  String get displayUnit => unitLabel ?? baseUnit;

  /// Harga per satuan dasar (dibulatkan 2 desimal, sama seperti backend).
  num get basePrice => conversionQty > 0 ? (agreedUnitPrice / conversionQty * 100).round() / 100 : agreedUnitPrice;

  factory ConsignmentItem.fromJson(Map<String, dynamic> json) {
    final product = (json['product'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final conv = parseInt(json['conversionQty'], fallback: 1);
    return ConsignmentItem(
      id: json['id'] as String,
      productId: json['productId'] as String? ?? product['id'] as String? ?? '',
      productName: product['name'] as String? ?? '-',
      sku: product['sku'] as String?,
      baseUnit: product['unit'] as String? ?? 'pcs',
      productUnitId: json['productUnitId'] as String?,
      unitLabel: json['unitLabel'] as String?,
      conversionQty: conv < 1 ? 1 : conv,
      qtySent: parseInt(json['qtySent']),
      baseQtySent: parseInt(json['baseQtySent']),
      baseQtySold: parseInt(json['baseQtySold']),
      baseQtyReturned: parseInt(json['baseQtyReturned']),
      baseQtyRemaining: parseInt(json['baseQtyRemaining']),
      agreedUnitPrice: parseNum(json['agreedUnitPrice']),
    );
  }
}

class ConsignmentSettlementLine {
  final String consignmentItemId;
  final int baseQty;

  ConsignmentSettlementLine({required this.consignmentItemId, required this.baseQty});

  factory ConsignmentSettlementLine.fromJson(Map<String, dynamic> json) => ConsignmentSettlementLine(
        consignmentItemId: json['consignmentItemId'] as String? ?? '',
        baseQty: parseInt(json['baseQty']),
      );
}

class ConsignmentSettlement {
  final String id;
  final String type; // SALE | RETURN
  final String? saleId;
  final String? invoiceNo;
  final String? note;
  final DateTime? voidedAt;
  final DateTime? createdAt;
  final List<ConsignmentSettlementLine> lines;

  ConsignmentSettlement({
    required this.id,
    required this.type,
    this.saleId,
    this.invoiceNo,
    this.note,
    this.voidedAt,
    this.createdAt,
    required this.lines,
  });

  bool get isVoided => voidedAt != null;

  factory ConsignmentSettlement.fromJson(Map<String, dynamic> json) {
    final lines = (json['lines'] as List<dynamic>?) ?? [];
    return ConsignmentSettlement(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'SALE',
      saleId: json['saleId'] as String?,
      invoiceNo: json['invoiceNo'] as String?,
      note: json['note'] as String?,
      voidedAt: _parseDate(json['voidedAt']),
      createdAt: _parseDate(json['createdAt']),
      lines: lines.map((e) => ConsignmentSettlementLine.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ConsignmentOrder {
  final String id;
  final String consignmentNo;
  final String status;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String sourceWarehouseId;
  final String sourceWarehouseName;
  final String? consignWarehouseId;
  final DateTime? sentAt;
  final DateTime? dueDate;
  final String? note;
  final String? cancelReason;
  final DateTime? createdAt;
  final ConsignmentSummary summary;
  final List<ConsignmentItem> items;
  final List<ConsignmentSettlement> settlements;

  ConsignmentOrder({
    required this.id,
    required this.consignmentNo,
    required this.status,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.sourceWarehouseId,
    required this.sourceWarehouseName,
    this.consignWarehouseId,
    this.sentAt,
    this.dueDate,
    this.note,
    this.cancelReason,
    this.createdAt,
    required this.summary,
    this.items = const [],
    this.settlements = const [],
  });

  String get statusLabel => kConsignmentStatusLabels[status] ?? status;

  /// Barang masih bisa dicatat terjual / diretur.
  bool get canSettleOrReturn => status == 'SENT' || status == 'PARTIALLY_SETTLED';

  /// Sesuai kontrak: batal dari DRAFT, atau SENT yang belum ada terjual/retur.
  bool get canCancel =>
      status == 'DRAFT' || (status == 'SENT' && items.every((e) => e.baseQtySold == 0 && e.baseQtyReturned == 0));

  factory ConsignmentOrder.fromJson(Map<String, dynamic> json) {
    final customer = (json['customer'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final source = (json['sourceWarehouse'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final items = (json['items'] as List<dynamic>?) ?? [];
    final settlements = (json['settlements'] as List<dynamic>?) ?? [];
    return ConsignmentOrder(
      id: json['id'] as String,
      consignmentNo: json['consignmentNo'] as String? ?? '-',
      status: json['status'] as String? ?? 'DRAFT',
      customerId: json['customerId'] as String? ?? customer['id'] as String? ?? '',
      customerName: customer['name'] as String? ?? '-',
      customerPhone: customer['phone'] as String?,
      sourceWarehouseId: json['sourceWarehouseId'] as String? ?? source['id'] as String? ?? '',
      sourceWarehouseName: source['name'] as String? ?? '-',
      consignWarehouseId: json['consignWarehouseId'] as String?,
      sentAt: _parseDate(json['sentAt']),
      dueDate: _parseDate(json['dueDate']),
      note: json['note'] as String?,
      cancelReason: json['cancelReason'] as String?,
      createdAt: _parseDate(json['createdAt']),
      summary: ConsignmentSummary.fromJson(json['summary'] as Map<String, dynamic>?),
      items: items.map((e) => ConsignmentItem.fromJson(e as Map<String, dynamic>)).toList(),
      settlements: settlements.map((e) => ConsignmentSettlement.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Hasil settle-sale: dokumen terbaru + ringkasan Sale yang dibuat.
class ConsignmentSettleResult {
  final ConsignmentOrder consignment;
  final String? saleId;
  final String? invoiceNo;
  final num? saleTotal;

  ConsignmentSettleResult({required this.consignment, this.saleId, this.invoiceNo, this.saleTotal});

  factory ConsignmentSettleResult.fromJson(Map<String, dynamic> json) {
    final sale = json['sale'] as Map<String, dynamic>?;
    return ConsignmentSettleResult(
      consignment: ConsignmentOrder.fromJson(json['consignment'] as Map<String, dynamic>),
      saleId: sale?['id'] as String?,
      invoiceNo: sale?['invoiceNo'] as String?,
      saleTotal: sale?['grandTotal'] == null ? null : parseNum(sale?['grandTotal']),
    );
  }
}

class OutletStockProduct {
  final String productId;
  final String name;
  final String? sku;
  final String unit;
  final int quantity;

  OutletStockProduct({required this.productId, required this.name, this.sku, required this.unit, required this.quantity});

  factory OutletStockProduct.fromJson(Map<String, dynamic> json) => OutletStockProduct(
        productId: json['productId'] as String? ?? '',
        name: json['name'] as String? ?? '-',
        sku: json['sku'] as String?,
        unit: json['unit'] as String? ?? 'pcs',
        quantity: parseInt(json['quantity']),
      );
}

class OutletStock {
  final String customerId;
  final String customerName;
  final String warehouseId;
  final String warehouseName;
  final List<OutletStockProduct> products;

  OutletStock({
    required this.customerId,
    required this.customerName,
    required this.warehouseId,
    required this.warehouseName,
    required this.products,
  });

  factory OutletStock.fromJson(Map<String, dynamic> json) {
    final products = (json['products'] as List<dynamic>?) ?? [];
    return OutletStock(
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '-',
      warehouseId: json['warehouseId'] as String? ?? '',
      warehouseName: json['warehouseName'] as String? ?? '-',
      products: products.map((e) => OutletStockProduct.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
