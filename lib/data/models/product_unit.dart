import '../../core/utils/num_parser.dart';

/// Satuan jual/beli tambahan di luar satuan dasar produk (Product.unit),
/// mis. produk dasarnya "Botol" tapi juga dijual per "Dus" dengan harga &
/// barcode sendiri. [conversionQty] = berapa banyak satuan dasar per 1 unit ini
/// (1 Dus = 24 Botol -> conversionQty 24).
class ProductUnit {
  final String id;
  final String name;
  final int conversionQty;
  final num sellPrice;
  final String? barcode;

  ProductUnit({
    required this.id,
    required this.name,
    required this.conversionQty,
    required this.sellPrice,
    this.barcode,
  });

  factory ProductUnit.fromJson(Map<String, dynamic> json) {
    return ProductUnit(
      id: json['id'] as String,
      name: json['name'] as String,
      conversionQty: parseInt(json['conversionQty']),
      sellPrice: parseNum(json['sellPrice']),
      barcode: json['barcode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'conversionQty': conversionQty,
        'sellPrice': sellPrice,
        if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
      };
}
