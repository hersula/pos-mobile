import 'package:flutter/widgets.dart';

import 'product.dart';
import 'product_unit.dart';

class CartItem {
  final Product product;
  final ProductUnit? unit; // null = dijual pakai satuan dasar produk (product.unit)
  int qty;
  num unitPrice; // bisa diubah manual oleh kasir (mis. harga nego), default sellPrice satuan/produk
  num discountAmount; // diskon nominal per item, opsional

  // Dibuat sekali saat item ditambahkan ke keranjang & disimpan di sini (bukan di
  // widget baris keranjang), supaya tidak ke-reset tiap kali keranjang rebuild —
  // pola yang sama dgn _POItemDraft di form Pengadaan Barang. Wajib dispose() saat
  // item dihapus dari keranjang (lihat CartProvider.removeItem/decrementQty/clear).
  late final TextEditingController discountCtrl;

  CartItem({required this.product, this.unit, this.qty = 1, num? unitPrice, this.discountAmount = 0})
      : unitPrice = unitPrice ?? (unit?.sellPrice ?? product.sellPrice) {
    discountCtrl = TextEditingController(text: discountAmount == 0 ? '' : discountAmount.toStringAsFixed(0));
  }

  /// Label satuan yang ditampilkan di keranjang/struk, mis. "Dus" atau satuan dasar produk.
  String get unitLabel => unit?.name ?? product.unit;

  num get subtotal => (qty * unitPrice) - discountAmount;

  void dispose() => discountCtrl.dispose();

  Map<String, dynamic> toSaleItemJson() => {
        'productId': product.id,
        if (unit != null) 'productUnitId': unit!.id,
        'qty': qty,
        'unitPrice': unitPrice,
        'discountAmount': discountAmount,
      };
}
