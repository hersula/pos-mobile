import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/pricing.dart';

class PriceLevelRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<PriceLevel>> getPriceLevels() async {
    final res = await _client.get(ApiEndpoints.priceLevels);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => PriceLevel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createPriceLevel(String name, {int sortOrder = 0}) async {
    await _client.post(ApiEndpoints.priceLevels, data: {'name': name, 'sortOrder': sortOrder});
  }

  Future<void> updatePriceLevel(String id, {String? name, int? sortOrder}) async {
    await _client.put(ApiEndpoints.priceLevelDetail(id), data: {
      if (name != null) 'name': name,
      if (sortOrder != null) 'sortOrder': sortOrder,
    });
  }

  Future<void> deletePriceLevel(String id) async {
    await _client.delete(ApiEndpoints.priceLevelDetail(id));
  }
}

class ProductUnitRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<ProductUnit>> getUnits(String productId) async {
    final res = await _client.get(ApiEndpoints.productUnits(productId));
    final data = res['data'] as Map<String, dynamic>;
    final list = data['units'] as List<dynamic>;
    return list.map((e) => ProductUnit.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createUnit(String productId, {required String name, required num conversionQty, String? barcode}) async {
    await _client.post(ApiEndpoints.productUnits(productId), data: {
      'name': name,
      'conversionQty': conversionQty,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
    });
  }

  Future<void> updateUnit(
    String productId,
    String unitId, {
    String? name,
    num? conversionQty,
    String? barcode,
  }) async {
    await _client.put(ApiEndpoints.productUnitDetail(productId, unitId), data: {
      if (name != null) 'name': name,
      if (conversionQty != null) 'conversionQty': conversionQty,
      if (barcode != null) 'barcode': barcode,
    });
  }

  Future<void> deleteUnit(String productId, String unitId) async {
    await _client.delete(ApiEndpoints.productUnitDetail(productId, unitId));
  }
}

class ProductPriceRepository {
  final ApiClient _client = ApiClient.instance;

  /// Ambil matriks harga produk: satuan dasar + satuan turunan x level harga.
  Future<Map<String, dynamic>> getPrices(String productId) async {
    final res = await _client.get(ApiEndpoints.productPrices(productId));
    return res['data'] as Map<String, dynamic>;
  }

  /// Simpan sekaligus beberapa entri harga (satu per kombinasi satuan+level).
  /// entries: [{ productUnitId: String?, priceLevelId: String, price: num }]
  Future<void> savePrices(String productId, List<Map<String, dynamic>> entries) async {
    await _client.put(ApiEndpoints.productPrices(productId), data: {'prices': entries});
  }
}
