import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/category.dart';
import '../models/product.dart';

class ProductRepository {
  final ApiClient _client = ApiClient.instance;

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

  Future<void> createProduct({
    required String name,
    String? categoryId,
    String? sku,
    String? barcode,
    String unit = 'pcs',
    required num costPrice,
    required num sellPrice,
    int minStock = 0,
    String? initialStockWarehouseId,
    int initialStockQty = 0,
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
      if (initialStockWarehouseId != null && initialStockQty > 0)
        'initialStock': {'warehouseId': initialStockWarehouseId, 'quantity': initialStockQty},
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
}

class WarehouseRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Warehouse>> getWarehouses() async {
    final res = await _client.get(ApiEndpoints.warehouses);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Warehouse.fromJson(e as Map<String, dynamic>)).toList();
  }
}
