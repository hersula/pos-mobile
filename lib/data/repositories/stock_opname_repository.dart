import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../models/stock_opname.dart';

class StockOpnamePage {
  final List<StockOpname> data;
  final int page;
  final int totalPages;
  final int total;

  StockOpnamePage({required this.data, required this.page, required this.totalPages, required this.total});
}

/// Finalisasi ditolak 409 STOCK_CONFLICT: stok akan negatif untuk [items].
class StockConflictException extends ApiException {
  final List<StockConflictItem> items;

  StockConflictException(super.message, this.items) : super(statusCode: 409);
}

/// Ambil `code` error backend (mis. INVALID_STATUS, NO_PRODUCTS) dari [e].
String? apiErrorCode(ApiException e) => e.data?['code'] as String?;

class StockOpnameRepository {
  final ApiClient _client = ApiClient.instance;

  Future<StockOpnamePage> getList({String? status, int page = 1, int pageSize = 20}) async {
    final res = await _client.get(ApiEndpoints.stockOpnames, query: {
      if (status != null) 'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    final list = (res['data'] as List<dynamic>).map((e) => StockOpname.fromJson(e as Map<String, dynamic>)).toList();
    final pg = res['pagination'] as Map<String, dynamic>?;
    return StockOpnamePage(
      data: list,
      page: (pg?['page'] as num?)?.toInt() ?? page,
      totalPages: (pg?['totalPages'] as num?)?.toInt() ?? 1,
      total: (pg?['total'] as num?)?.toInt() ?? list.length,
    );
  }

  Future<StockOpname> getDetail(String id) async {
    final res = await _client.get(ApiEndpoints.stockOpnameDetail(id));
    return StockOpname.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<StockOpname> create({required String warehouseId, String? categoryId, String? note}) async {
    final res = await _client.post(ApiEndpoints.stockOpnames, data: {
      'warehouseId': warehouseId,
      if (categoryId != null) 'categoryId': categoryId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return StockOpname.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Simpan hitungan parsial. [counts]: itemId -> qty (null = hapus hitungan).
  /// Mengembalikan header terbaru (summary).
  Future<StockOpname> saveCounts(String id, Map<String, num?> counts) async {
    final res = await _client.patch(ApiEndpoints.stockOpnameItems(id), data: {
      'items': [
        for (final e in counts.entries) {'itemId': e.key, 'countedQty': e.value},
      ],
    });
    return StockOpname.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<FinalizeResult> finalize(String id, {bool clampToZero = false}) async {
    try {
      final res = await _client.post(ApiEndpoints.stockOpnameFinalize(id), data: {'clampToZero': clampToZero});
      final r = (res['result'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      int n(String k) => (r[k] as num?)?.toInt() ?? 0;
      return FinalizeResult(
        opname: StockOpname.fromJson(res['data'] as Map<String, dynamic>),
        adjustedItems: n('adjustedItems'),
        unchangedItems: n('unchangedItems'),
        uncountedItems: n('uncountedItems'),
        clampedItems: n('clampedItems'),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409 && apiErrorCode(e) == 'STOCK_CONFLICT') {
        throw StockConflictException(e.message, parseConflictItems(e.data));
      }
      rethrow;
    }
  }

  Future<StockOpname> cancel(String id, String reason) async {
    final res = await _client.post(ApiEndpoints.stockOpnameCancel(id), data: {'reason': reason});
    return StockOpname.fromJson(res['data'] as Map<String, dynamic>);
  }
}

List<StockConflictItem> parseConflictItems(Map<String, dynamic>? body) {
  final details = body?['details'];
  final list = details is Map ? details['items'] : null;
  if (list is! List) return const [];
  return list.whereType<Map<String, dynamic>>().map(StockConflictItem.fromJson).toList();
}
