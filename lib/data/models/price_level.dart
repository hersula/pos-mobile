import '../../core/utils/num_parser.dart';

/// Master level harga per tenant (mis. "Grosir", "Member"), dipilih manual oleh
/// kasir per transaksi di halaman Kasir. "Umum"/default TIDAK direpresentasikan
/// sebagai PriceLevel -- itu cukup Product.sellPrice (lihat [Product.priceForLevel]).
class PriceLevel {
  final String id;
  final String name;
  final int productCount;

  PriceLevel({required this.id, required this.name, this.productCount = 0});

  factory PriceLevel.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return PriceLevel(
      id: json['id'] as String,
      name: json['name'] as String,
      productCount: count?['prices'] as int? ?? 0,
    );
  }
}

/// Override harga jual produk utk satu level tertentu (hanya berlaku di satuan
/// dasar produk -- satuan tambahan/ProductUnit tetap 1 harga tunggal).
class ProductPrice {
  final String priceLevelId;
  final num sellPrice;

  ProductPrice({required this.priceLevelId, required this.sellPrice});

  factory ProductPrice.fromJson(Map<String, dynamic> json) {
    return ProductPrice(
      priceLevelId: json['priceLevelId'] as String,
      sellPrice: parseNum(json['sellPrice']),
    );
  }

  Map<String, dynamic> toJson() => {'priceLevelId': priceLevelId, 'sellPrice': sellPrice};
}
