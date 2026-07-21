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
    required String paymentMethod, // CASH | CREDIT | TRANSFER
    required List<PurchaseOrderItem> items,
  }) async {
    final res = await _client.post(ApiEndpoints.purchaseOrders, data: {
      if (supplierId != null) 'supplierId': supplierId,
      'warehouseId': warehouseId,
      'paymentMethod': paymentMethod,
      'items': items.map((e) => e.toJson()).toList(),
    });
    return PurchaseOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> receivePurchaseOrder(String id) async {
    await _client.post(ApiEndpoints.purchaseOrderReceive(id));
  }

  /// Catat pelunasan/cicilan hutang usaha untuk PO bermetode CREDIT (tempo).
  Future<PurchaseOrder> payDebt(String id, {required String method, required num amount, String? referenceNo}) async {
    final res = await _client.post(ApiEndpoints.purchaseOrderPayments(id), data: {
      'method': method,
      'amount': amount,
      if (referenceNo != null && referenceNo.isNotEmpty) 'referenceNo': referenceNo,
    });
    return PurchaseOrder.fromJson(res['data'] as Map<String, dynamic>);
  }
}
