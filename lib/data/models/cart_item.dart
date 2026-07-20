import 'product.dart';

class CartItem {
  final Product product;
  int qty;
  num unitPrice; // bisa diubah manual oleh kasir (mis. harga nego), default sellPrice
  num discountAmount; // diskon nominal per item, opsional

  CartItem({required this.product, this.qty = 1, num? unitPrice, this.discountAmount = 0})
      : unitPrice = unitPrice ?? product.sellPrice;

  num get subtotal => (qty * unitPrice) - discountAmount;

  Map<String, dynamic> toSaleItemJson() => {
        'productId': product.id,
        'qty': qty,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
      };
}
