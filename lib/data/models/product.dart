import '../../core/utils/num_parser.dart';
import 'category.dart';
import 'price_level.dart';
import 'product_unit.dart';

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
  final String? imageUrl;
  final bool isActive;
  final int totalStock;
  final List<ProductStock> stocks;
  final List<ProductUnit> units;
  final List<ProductPrice> prices;

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
    this.imageUrl,
    required this.isActive,
    required this.totalStock,
    required this.stocks,
    this.units = const [],
    this.prices = const [],
  });

  /// Produk ini punya pilihan satuan selain satuan dasar (mis. Botol + Dus)?
  bool get hasMultipleUnits => units.isNotEmpty;

  bool get isLowStock => totalStock <= minStock;

  /// Harga jual satuan dasar utk level tertentu -- null/tidak ada override = pakai
  /// [sellPrice] ("Umum"). Hanya berlaku utk satuan dasar; satuan tambahan (Dus dkk)
  /// selalu pakai harganya sendiri, tidak terpengaruh level.
  num priceForLevel(String? priceLevelId) {
    if (priceLevelId == null) return sellPrice;
    final override = prices.where((p) => p.priceLevelId == priceLevelId);
    return override.isNotEmpty ? override.first.sellPrice : sellPrice;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final stocksJson = (json['stocks'] as List<dynamic>?) ?? [];
    final stocks = stocksJson.map((s) => ProductStock.fromJson(s as Map<String, dynamic>)).toList();
    final unitsJson = (json['units'] as List<dynamic>?) ?? [];
    final units = unitsJson.map((u) => ProductUnit.fromJson(u as Map<String, dynamic>)).toList();
    final pricesJson = (json['prices'] as List<dynamic>?) ?? [];
    final prices = pricesJson.map((p) => ProductPrice.fromJson(p as Map<String, dynamic>)).toList();

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
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      totalStock: totalStockFromField != null ? parseInt(totalStockFromField) : computedTotal,
      stocks: stocks,
      units: units,
      prices: prices,
    );
  }
}
