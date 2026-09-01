import 'package:flutter/foundation.dart';
import '../data/models/cart_item.dart';
import '../data/models/customer.dart';
import '../data/models/product.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  String discountType = 'NOMINAL'; // PERCENT | NOMINAL
  num discountValue = 0;
  num taxPercent = 11;
  bool useTax = false; // default non-PPN
  Customer? selectedCustomer;
  String? note;

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

  void addProduct(Product product) {
    final existingIndex = _items.indexWhere((e) => e.product.id == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].qty += 1;
    } else {
      _items.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void incrementQty(String productId) {
    final item = _items.firstWhere((e) => e.product.id == productId);
    item.qty += 1;
    notifyListeners();
  }

  void decrementQty(String productId) {
    final item = _items.firstWhere((e) => e.product.id == productId);
    if (item.qty <= 1) {
      _items.removeWhere((e) => e.product.id == productId);
    } else {
      item.qty -= 1;
    }
    notifyListeners();
  }

  void updateQty(String productId, int qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }
    final item = _items.firstWhere((e) => e.product.id == productId);
    item.qty = qty;
    notifyListeners();
  }

  void updateItemDiscount(String productId, num discount) {
    final item = _items.firstWhere((e) => e.product.id == productId);
    item.discountAmount = discount;
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((e) => e.product.id == productId);
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
    _items.clear();
    discountType = 'NOMINAL';
    discountValue = 0;
    taxPercent = 11;
    useTax = false;
    selectedCustomer = null;
    note = null;
    notifyListeners();
  }

  num _round2(num n) => (n * 100).round() / 100;
}
