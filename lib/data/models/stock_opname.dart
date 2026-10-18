import '../../core/utils/num_parser.dart';

const kOpnameStatusLabels = {
  'DRAFT': 'Draft',
  'COMPLETED': 'Selesai',
  'CANCELLED': 'Batal',
};

DateTime? _date(dynamic v) => v is String ? DateTime.tryParse(v) : null;

class OpnameSummary {
  final int totalItems;
  final int countedItems;
  final num surplusQty;
  final num shortageQty;
  final num surplusValue;
  final num shortageValue; // positif
  final num netValue;

  const OpnameSummary({
    this.totalItems = 0,
    this.countedItems = 0,
    this.surplusQty = 0,
    this.shortageQty = 0,
    this.surplusValue = 0,
    this.shortageValue = 0,
    this.netValue = 0,
  });

  factory OpnameSummary.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const OpnameSummary();
    return OpnameSummary(
      totalItems: parseInt(j['totalItems']),
      countedItems: parseInt(j['countedItems']),
      surplusQty: parseNum(j['surplusQty']),
      shortageQty: parseNum(j['shortageQty']),
      surplusValue: parseNum(j['surplusValue']),
      shortageValue: parseNum(j['shortageValue']),
      netValue: parseNum(j['netValue']),
    );
  }
}

class OpnameItem {
  final String id;
  final String productId;
  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final num systemQty;
  final num? countedQty; // null = belum dihitung
  final num unitCost;
  final num diffValue;
  final num? currentQty;
  final bool stockChanged;
  final num? appliedDiff;

  const OpnameItem({
    required this.id,
    required this.productId,
    required this.name,
    this.sku,
    this.barcode,
    this.unit = '',
    required this.systemQty,
    this.countedQty,
    this.unitCost = 0,
    this.diffValue = 0,
    this.currentQty,
    this.stockChanged = false,
    this.appliedDiff,
  });

  bool get counted => countedQty != null;

  /// Selisih terhadap snapshot; null bila belum dihitung.
  num? get diff => countedQty == null ? null : countedQty! - systemQty;

  factory OpnameItem.fromJson(Map<String, dynamic> j) {
    final p = (j['product'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return OpnameItem(
      id: j['id'] as String,
      productId: (j['productId'] ?? p['id'] ?? '') as String,
      name: (p['name'] ?? '') as String,
      sku: p['sku'] as String?,
      barcode: p['barcode'] as String?,
      unit: (p['unit'] ?? '') as String,
      systemQty: parseNum(j['systemQty']),
      countedQty: j['countedQty'] == null ? null : parseNum(j['countedQty']),
      unitCost: parseNum(j['unitCost']),
      diffValue: parseNum(j['diffValue']),
      currentQty: j['currentQty'] == null ? null : parseNum(j['currentQty']),
      stockChanged: j['stockChanged'] == true,
      appliedDiff: j['appliedDiff'] == null ? null : parseNum(j['appliedDiff']),
    );
  }

  OpnameItem withCounted(num? qty) => OpnameItem(
        id: id,
        productId: productId,
        name: name,
        sku: sku,
        barcode: barcode,
        unit: unit,
        systemQty: systemQty,
        countedQty: qty,
        unitCost: unitCost,
        diffValue: qty == null ? 0 : (qty - systemQty) * unitCost,
        currentQty: currentQty,
        stockChanged: stockChanged,
        appliedDiff: appliedDiff,
      );
}

class StockOpname {
  final String id;
  final String opnameNo;
  final String status;
  final String warehouseId;
  final String warehouseName;
  final String? categoryId;
  final String? note;
  final String? cancelReason;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final OpnameSummary summary;
  final List<OpnameItem> items; // kosong pada daftar

  const StockOpname({
    required this.id,
    required this.opnameNo,
    required this.status,
    required this.warehouseId,
    this.warehouseName = '',
    this.categoryId,
    this.note,
    this.cancelReason,
    this.completedAt,
    this.createdAt,
    this.summary = const OpnameSummary(),
    this.items = const [],
  });

  bool get isDraft => status == 'DRAFT';
  String get statusLabel => kOpnameStatusLabels[status] ?? status;

  factory StockOpname.fromJson(Map<String, dynamic> j, {List<dynamic>? itemsOverride}) {
    final wh = j['warehouse'] as Map<String, dynamic>?;
    final rawItems = itemsOverride ?? (j['items'] as List<dynamic>?) ?? const [];
    return StockOpname(
      id: j['id'] as String,
      opnameNo: (j['opnameNo'] ?? '') as String,
      status: (j['status'] ?? 'DRAFT') as String,
      warehouseId: (j['warehouseId'] ?? wh?['id'] ?? '') as String,
      warehouseName: (wh?['name'] ?? '') as String,
      categoryId: j['categoryId'] as String?,
      note: j['note'] as String?,
      cancelReason: j['cancelReason'] as String?,
      completedAt: _date(j['completedAt']),
      createdAt: _date(j['createdAt']),
      summary: OpnameSummary.fromJson(j['summary'] as Map<String, dynamic>?),
      items: rawItems.map((e) => OpnameItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Satu item konflik pada 409 STOCK_CONFLICT.
class StockConflictItem {
  final String productName;
  final num currentQty;
  final num diff;

  const StockConflictItem({required this.productName, required this.currentQty, required this.diff});

  factory StockConflictItem.fromJson(Map<String, dynamic> j) => StockConflictItem(
        productName: (j['productName'] ?? '') as String,
        currentQty: parseNum(j['currentQty']),
        diff: parseNum(j['diff']),
      );
}

class FinalizeResult {
  final StockOpname opname;
  final int adjustedItems;
  final int unchangedItems;
  final int uncountedItems;
  final int clampedItems;

  const FinalizeResult({
    required this.opname,
    this.adjustedItems = 0,
    this.unchangedItems = 0,
    this.uncountedItems = 0,
    this.clampedItems = 0,
  });
}

/// Format qty tanpa ".0" untuk bilangan bulat.
String fmtQty(num v) => v == v.truncate() ? v.truncate().toString() : v.toString();
