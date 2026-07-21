import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/purchase_order.dart';

class PurchaseOrderRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<PurchaseOrder>> getPurchaseOrders({String? status}) async {
    final res = await _client.get(ApiEndpoints.purchaseOrders, query: {
      if (status != null) 'status': status,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => PurchaseOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PurchaseOrder> getPurchaseOrderDetail(String id) async {
    final res = await _client.get(ApiEndpoints.purchaseOrderDetail(id));
    return PurchaseOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<PurchaseOrder> createPurchaseOrder({
    String? supplierId,
    required String warehouseId,
    required List<PurchaseOrderItem> items,
  }) async {
    final res = await _client.post(ApiEndpoints.purchaseOrders, data: {
      if (supplierId != null) 'supplierId': supplierId,
      'warehouseId': warehouseId,
      'items': items.map((e) => e.toJson()).toList(),
    });
    return PurchaseOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> receivePurchaseOrder(String id) async {
    await _client.post(ApiEndpoints.purchaseOrderReceive(id));
  }
}
