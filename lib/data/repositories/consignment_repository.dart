import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/consignment.dart';

/// Baris input create/update konsinyasi.
class ConsignmentItemInput {
  final String productId;
  final String? productUnitId;
  final int qty;
  final num agreedUnitPrice;

  ConsignmentItemInput({required this.productId, this.productUnitId, required this.qty, required this.agreedUnitPrice});

  Map<String, dynamic> toJson() => {
        'productId': productId,
        if (productUnitId != null) 'productUnitId': productUnitId,
        'qty': qty,
        'agreedUnitPrice': agreedUnitPrice,
      };
}

/// Baris settle-sale / retur. [useBaseUnit] true = qty dalam satuan dasar.
class ConsignmentLineInput {
  final String consignmentItemId;
  final int qty;
  final bool useBaseUnit;
  final num? unitPrice; // hanya settle-sale; null = harga default backend

  ConsignmentLineInput({required this.consignmentItemId, required this.qty, this.useBaseUnit = false, this.unitPrice});

  Map<String, dynamic> toJson({bool withPrice = false}) => {
        'consignmentItemId': consignmentItemId,
        'qty': qty,
        'useBaseUnit': useBaseUnit,
        if (withPrice && unitPrice != null) 'unitPrice': unitPrice,
      };
}

class ConsignmentPage {
  final List<ConsignmentOrder> data;
  final int page;
  final int totalPages;
  final int total;

  ConsignmentPage({required this.data, required this.page, required this.totalPages, required this.total});
}

class ConsignmentRepository {
  final ApiClient _client = ApiClient.instance;

  Future<ConsignmentPage> getConsignments({String? status, String? customerId, int page = 1, int pageSize = 50}) async {
    final res = await _client.get(ApiEndpoints.consignments, query: {
      if (status != null) 'status': status,
      if (customerId != null) 'customerId': customerId,
      'page': page,
      'pageSize': pageSize,
    });
    final list = (res['data'] as List<dynamic>).map((e) => ConsignmentOrder.fromJson(e as Map<String, dynamic>)).toList();
    final pg = res['pagination'] as Map<String, dynamic>?;
    return ConsignmentPage(
      data: list,
      page: (pg?['page'] as num?)?.toInt() ?? page,
      totalPages: (pg?['totalPages'] as num?)?.toInt() ?? 1,
      total: (pg?['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<ConsignmentOrder> getDetail(String id) async {
    final res = await _client.get(ApiEndpoints.consignmentDetail(id));
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _body({
    required String customerId,
    required String sourceWarehouseId,
    DateTime? dueDate,
    String? note,
    required List<ConsignmentItemInput> items,
  }) =>
      {
        'customerId': customerId,
        'sourceWarehouseId': sourceWarehouseId,
        if (dueDate != null) 'dueDate': dueDate.toIso8601String().substring(0, 10),
        if (note != null && note.isNotEmpty) 'note': note,
        'items': items.map((e) => e.toJson()).toList(),
      };

  Future<ConsignmentOrder> create({
    required String customerId,
    required String sourceWarehouseId,
    DateTime? dueDate,
    String? note,
    required List<ConsignmentItemInput> items,
  }) async {
    final res = await _client.post(
      ApiEndpoints.consignments,
      data: _body(customerId: customerId, sourceWarehouseId: sourceWarehouseId, dueDate: dueDate, note: note, items: items),
    );
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Hanya untuk status DRAFT; semua field dikirim ulang.
  Future<ConsignmentOrder> update(
    String id, {
    required String customerId,
    required String sourceWarehouseId,
    DateTime? dueDate,
    String? note,
    required List<ConsignmentItemInput> items,
  }) async {
    final res = await _client.put(
      ApiEndpoints.consignmentDetail(id),
      data: _body(customerId: customerId, sourceWarehouseId: sourceWarehouseId, dueDate: dueDate, note: note, items: items),
    );
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ConsignmentOrder> send(String id) async {
    final res = await _client.post(ApiEndpoints.consignmentSend(id), data: {});
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ConsignmentSettleResult> settleSale(String id, {required List<ConsignmentLineInput> lines, String? note}) async {
    final res = await _client.post(ApiEndpoints.consignmentSettleSale(id), data: {
      'lines': lines.map((e) => e.toJson(withPrice: true)).toList(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ConsignmentSettleResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ConsignmentOrder> returnItems(String id, {required List<ConsignmentLineInput> lines, String? note}) async {
    final res = await _client.post(ApiEndpoints.consignmentReturn(id), data: {
      'lines': lines.map((e) => e.toJson()).toList(),
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<ConsignmentOrder> cancel(String id, {required String reason}) async {
    final res = await _client.post(ApiEndpoints.consignmentCancel(id), data: {'reason': reason});
    return ConsignmentOrder.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<List<OutletStock>> getOutletStock({String? customerId}) async {
    final res = await _client.get(ApiEndpoints.consignmentOutletStock, query: {
      if (customerId != null) 'customerId': customerId,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => OutletStock.fromJson(e as Map<String, dynamic>)).toList();
  }
}
