import '../../core/utils/num_parser.dart';
import 'category.dart';

class ProductStock {
  final String warehouseId;
  final String warehouseName;
  final int quantity;

  ProductStock({required this.warehouseId, required this.warehouseName, required this.quantity});

  factory ProductStock.fromJson(Map<String, dynamic> json) {
    final warehouse = json['warehouse'] as Map<String, dynamic>?;
    return ProductStock(
      warehouseId: json['warehouseId'] as String? ?? warehouse?['id'] as String? ?? '',
      warehouseName: warehouse?['name'] as String? ?? '-',
      quantity: parseInt(json['quantity']),
    );
  }
}

class Product {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final String? sku;
  final String? barcode;
  final String name;
  final String unit;
  final num costPrice;
  final num sellPrice;
  final int minStock;
  final bool isActive;
  final int totalStock;
  final List<ProductStock> stocks;

  Product({
    required this.id,
    this.categoryId,
    this.categoryName,
    this.sku,
    this.barcode,
    required this.name,
    required this.unit,
    required this.costPrice,
    required this.sellPrice,
    required this.minStock,
    required this.isActive,
    required this.totalStock,
    required this.stocks,
  });

  bool get isLowStock => totalStock <= minStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final stocksJson = (json['stocks'] as List<dynamic>?) ?? [];
    final stocks = stocksJson.map((s) => ProductStock.fromJson(s as Map<String, dynamic>)).toList();

    final totalStockFromField = json['totalStock'];
    final computedTotal = stocks.fold<int>(0, (sum, s) => sum + s.quantity);

    return Product(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: category?['name'] as String?,
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      name: json['name'] as String,
      unit: json['unit'] as String? ?? 'pcs',
      costPrice: parseNum(json['costPrice']),
      sellPrice: parseNum(json['sellPrice']),
      minStock: parseInt(json['minStock']),
      isActive: json['isActive'] as bool? ?? true,
      totalStock: totalStockFromField != null ? parseInt(totalStockFromField) : computedTotal,
      stocks: stocks,
    );
  }
}
