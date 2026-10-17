import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/category.dart';
import '../models/price_level.dart';
import '../models/product.dart';

/// Hasil lookup barcode: produknya, plus id satuan tambahan kalau yang cocok
/// adalah barcode satuan tambahan (mis. barcode kemasan "Dus"), bukan satuan dasar.
class ProductScanResult {
  final Product product;
  final String? matchedUnitId;
  ProductScanResult({required this.product, this.matchedUnitId});
}

class ProductRepository {
  final ApiClient _client = ApiClient.instance;

  /// Upload gambar produk ke server, balikan path relatif (mis. `/uploads/product-123.jpg`)
  /// yang nanti dikirim sebagai `imageUrl` saat create/update produk.
  Future<String> uploadProductImage(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final res = await _client.postMultipart(
      ApiEndpoints.upload,
      formData: formData,
      onProgress: onProgress,
    );
    final data = res['data'] as Map<String, dynamic>?;
    final url = data?['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Server tidak mengembalikan URL gambar');
    }
    return url;
  }

  Future<List<Product>> getProducts({String? search, String? categoryId, bool lowStockOnly = false}) async {
    final res = await _client.get(ApiEndpoints.products, query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'categoryId': categoryId,
      if (lowStockOnly) 'lowStock': 'true',
      'pageSize': 100,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> getProduct(String id) async {
    final res = await _client.get('${ApiEndpoints.products}/$id');
    return Product.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Cari produk lewat hasil scan barcode — cocok dgn barcode satuan dasar ATAU
  /// barcode salah satu satuan tambahan (mis. barcode kemasan "Dus").
  Future<ProductScanResult> scanBarcode(String code) async {
    final res = await _client.get(ApiEndpoints.productScan, query: {'code': code});
    final data = res['data'] as Map<String, dynamic>;
    return ProductScanResult(
      product: Product.fromJson(data['product'] as Map<String, dynamic>),
      matchedUnitId: data['matchedUnitId'] as String?,
    );
  }

  Future<void> createProduct({
    required String name,
    String? categoryId,
    String? sku,
    String? barcode,
    String unit = 'pcs',
    required num costPrice,
    required num sellPrice,
    int minStock = 0,
    String? imageUrl,
    String? initialStockWarehouseId,
    int initialStockQty = 0,
    List<Map<String, dynamic>>? units,
    List<Map<String, dynamic>>? prices,
  }) async {
    await _client.post(ApiEndpoints.products, data: {
      'name': name,
      if (categoryId != null) 'categoryId': categoryId,
      if (sku != null && sku.isNotEmpty) 'sku': sku,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      'unit': unit,
      'costPrice': costPrice,
      'sellPrice': sellPrice,
      'minStock': minStock,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      if (initialStockWarehouseId != null && initialStockQty > 0)
        'initialStock': {'warehouseId': initialStockWarehouseId, 'quantity': initialStockQty},
      if (units != null) 'units': units,
      if (prices != null) 'prices': prices,
    });
  }

  Future<void> updateProduct(String id, Map<String, dynamic> changes) async {
    await _client.put('${ApiEndpoints.products}/$id', data: changes);
  }

  Future<void> deactivateProduct(String id) async {
    await _client.delete('${ApiEndpoints.products}/$id');
  }
}

class CategoryRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Category>> getCategories() async {
    final res = await _client.get(ApiEndpoints.categories);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> createCategory(String name) async {
    final res = await _client.post(ApiEndpoints.categories, data: {'name': name});
    return Category.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<Category> updateCategory(String id, String name) async {
    final res = await _client.put(ApiEndpoints.categoryDetail(id), data: {'name': name});
    return Category.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _client.delete(ApiEndpoints.categoryDetail(id));
  }
}

class PriceLevelRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<PriceLevel>> getPriceLevels() async {
    final res = await _client.get(ApiEndpoints.priceLevels);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => PriceLevel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPriceLevel(String name) async {
    await _client.post(ApiEndpoints.priceLevels, data: {'name': name});
  }

  Future<void> updatePriceLevel(String id, String name) async {
    await _client.put(ApiEndpoints.priceLevelDetail(id), data: {'name': name});
  }

  Future<void> deletePriceLevel(String id) async {
    await _client.delete(ApiEndpoints.priceLevelDetail(id));
  }
}

class WarehouseRepository {
  final ApiClient _client = ApiClient.instance;

  /// [type]: STORE (default backend), CONSIGNMENT, atau ALL. Checkout/PO memakai
  /// default (STORE); `ALL` hanya untuk layar konsinyasi bila perlu.
  Future<List<Warehouse>> getWarehouses({String? type}) async {
    final res = await _client.get(ApiEndpoints.warehouses, query: {
      if (type != null) 'type': type,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }
}
