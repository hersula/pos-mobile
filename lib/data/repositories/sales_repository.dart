import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/cart_item.dart';
import '../models/sale.dart';

class SalesRepository {
  final ApiClient _client = ApiClient.instance;

  Future<Sale> createSale({
    required String warehouseId,
    String? customerId,
    required List<CartItem> items,
    required String discountType, // PERCENT | NOMINAL
    required num discountValue,
    required num taxPercent,
    required List<SalePayment> payments,
    String? note,
  }) async {
    final res = await _client.post(ApiEndpoints.sales, data: {
      'warehouseId': warehouseId,
      if (customerId != null) 'customerId': customerId,
      'items': items.map((e) => e.toSaleItemJson()).toList(),
      'discountType': discountType,
      'discountValue': discountValue,
      'taxPercent': taxPercent,
      'payments': payments.map((p) => p.toJson()).toList(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<Sale>> getSales({String? status, String? dateFrom, String? dateTo}) async {
    final res = await _client.get(ApiEndpoints.sales, query: {
      if (status != null) 'status': status,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      'pageSize': 50,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Sale.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Sale> getSaleDetail(String id) async {
    final res = await _client.get(ApiEndpoints.saleDetail(id));
    return Sale.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> cancelSale(String id, String reason) async {
    await _client.post(ApiEndpoints.saleCancel(id), data: {'reason': reason});
  }

  Future<void> addPayment(String id, SalePayment payment) async {
    await _client.post(ApiEndpoints.salePayments(id), data: payment.toJson());
  }
}
