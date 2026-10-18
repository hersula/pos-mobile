import '../../core/utils/num_parser.dart';

/// Level/tingkatan harga jual milik tenant, mis. "Eceran", "Reseller", "Grosir".
class PriceLevel {
  final String id;
  final String name;
  final int sortOrder;

  PriceLevel({required this.id, required this.name, required this.sortOrder});

  factory PriceLevel.fromJson(Map<String, dynamic> json) {
    return PriceLevel(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: parseInt(json['sortOrder']),
    );
  }
}

/// Satuan turunan produk di luar satuan dasar (Product.unit), mis. "Box" = 12 pcs.
class ProductUnit {
  final String id;
  final String productId;
  final String name;
  final num conversionQty; // jumlah satuan dasar dalam 1 unit ini
  final String? barcode;

  ProductUnit({
    required this.id,
    required this.productId,
    required this.name,
    required this.conversionQty,
    this.barcode,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: json['id'] as String,
      productId: json['productId'] as String,
      name: json['name'] as String,
      conversionQty: parseNum(json['conversionQty'], fallback: 1),
      barcode: json['barcode'] as String?,
    );
  }
}

/// Harga jual produk untuk kombinasi (satuan, level harga).
/// productUnitId null = harga berlaku untuk satuan dasar produk.
class ProductPrice {
  final String id;
  final String? productUnitId;
  final String priceLevelId;
  final num price;

  ProductPrice({required this.id, this.productUnitId, required this.priceLevelId, required this.price});

  factory ProductPrice.fromJson(Map<String, dynamic> json) {
    return ProductPrice(
      id: json['id'] as String,
      productUnitId: json['productUnitId'] as String?,
      priceLevelId: json['priceLevelId'] as String,
      price: parseNum(json['price']),
    );
  }
}
