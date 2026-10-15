import 'package:flutter/foundation.dart';
import '../data/models/cart_item.dart';
import '../data/models/customer.dart';
import '../data/models/price_level.dart';
import '../data/models/product.dart';
import '../data/models/product_unit.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  String discountType = 'NOMINAL'; // PERCENT | NOMINAL
  num discountValue = 0;
  num taxPercent = 11;
  bool useTax = false; // default non-PPN
  Customer? selectedCustomer;
  String? note;

  // Level harga aktif utk transaksi ini (null = "Umum"/default). Dipilih kasir sekali
  // di halaman Kasir sebelum menambahkan produk -- lihat Product.priceForLevel().
  // Hanya memengaruhi harga satuan DASAR; satuan tambahan (Dus dkk) tidak terpengaruh.
  PriceLevel? activePriceLevel;

  bool get isEmpty => _items.isEmpty;
  int get totalQty => _items.fold(0, (sum, e) => sum + e.qty);

  num get subtotal => _items.fold<num>(0, (sum, e) => sum + e.subtotal);

  num get discountAmount {
    if (discountType == 'PERCENT') {
      return _round2(subtotal * (discountValue / 100));
    }
    return _round2(discountValue);
  }

  num get taxableAmount {
    final t = subtotal - discountAmount;
    return t < 0 ? 0 : _round2(t);
  }

  num get taxAmount => useTax ? _round2(taxableAmount * (taxPercent / 100)) : 0;

  num get grandTotal => _round2(taxableAmount + taxAmount);

  // Produk yang sama tapi beda satuan (mis. Aqua per Botol vs per Dus) dianggap
  // baris keranjang yang BERBEDA, jadi pencarian baris selalu cocokkan productId + unitId.
  bool _matches(CartItem e, String productId, String? unitId) => e.product.id == productId && e.unit?.id == unitId;

  void addProduct(Product product, {ProductUnit? unit, num? unitPriceOverride}) {
    final existingIndex = _items.indexWhere((e) => _matches(e, product.id, unit?.id));
    if (existingIndex >= 0) {
      _items[existingIndex].qty += 1;
    } else {
      _items.add(CartItem(product: product, unit: unit, unitPrice: unitPriceOverride));
    }
    notifyListeners();
  }

  void setPriceLevel(PriceLevel? level) {
    activePriceLevel = level;
    notifyListeners();
  }

  void incrementQty(String productId, {String? unitId}) {
    final item = _items.firstWhere((e) => _matches(e, productId, unitId));
    item.qty += 1;
    notifyListeners();
  }

  void decrementQty(String productId, {String? unitId}) {
    final item = _items.firstWhere((e) => _matches(e, productId, unitId));
    if (item.qty <= 1) {
      item.dispose();
      _items.removeWhere((e) => _matches(e, productId, unitId));
    } else {
      item.qty -= 1;
    }
    notifyListeners();
  }

  void updateQty(String productId, int qty, {String? unitId}) {
    if (qty <= 0) {
      removeItem(productId, unitId: unitId);
      return;
    }
    final item = _items.firstWhere((e) => _matches(e, productId, unitId));
    item.qty = qty;
    notifyListeners();
  }

  void updateItemDiscount(String productId, num discount, {String? unitId}) {
    final item = _items.firstWhere((e) => _matches(e, productId, unitId));
    item.discountAmount = discount;
    notifyListeners();
  }

  void removeItem(String productId, {String? unitId}) {
    for (final e in _items.where((e) => _matches(e, productId, unitId))) {
      e.dispose();
    }
    _items.removeWhere((e) => _matches(e, productId, unitId));
    notifyListeners();
  }

  void setDiscount(String type, num value) {
    discountType = type;
    discountValue = value;
    notifyListeners();
  }

  void setTaxPercent(num value) {
    taxPercent = value;
    notifyListeners();
  }

  void setUseTax(bool value) {
    useTax = value;
    notifyListeners();
  }

  void setCustomer(Customer? customer) {
    selectedCustomer = customer;
    notifyListeners();
  }

  void setNote(String? value) {
    note = value;
  }

  void clear() {
    for (final e in _items) {
      e.dispose();
    }
    _items.clear();
    discountType = 'NOMINAL';
    discountValue = 0;
    taxPercent = 11;
    useTax = false;
    selectedCustomer = null;
    note = null;
    activePriceLevel = null;
    notifyListeners();
  }

  num _round2(num n) => (n * 100).round() / 100;
}
