import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../data/models/stock_opname.dart';
import '../data/repositories/stock_opname_repository.dart';

/// Daftar sesi opname (filter status, infinite scroll). Pencarian nomor/gudang
/// dilakukan lokal pada data yang sudah dimuat (kontrak tidak punya parameter search).
class StockOpnameProvider extends ChangeNotifier {
  StockOpnameProvider({StockOpnameRepository? repo}) : repo = repo ?? StockOpnameRepository();

  final StockOpnameRepository repo;

  List<StockOpname> sessions = [];
  String? statusFilter;
  String search = '';
  bool loading = false;
  String? error;

  static const int pageSize = 20;
  int _page = 1;
  int _totalPages = 1;
  bool loadingMore = false;
  int _gen = 0;

  bool get hasMore => _page < _totalPages;

  List<StockOpname> get filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return sessions;
    return sessions.where((s) => s.opnameNo.toLowerCase().contains(q) || s.warehouseName.toLowerCase().contains(q)).toList();
  }

  void setSearch(String v) {
    search = v;
    notifyListeners();
  }

  void setStatusFilter(String? v) {
    if (statusFilter == v) return;
    statusFilter = v;
    load();
  }

  Future<void> load() async {
    final gen = ++_gen;
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      final page = await repo.getList(status: statusFilter, page: 1, pageSize: pageSize);
      if (gen != _gen) return;
      sessions = page.data;
      _page = page.page;
      _totalPages = page.totalPages;
    } on ApiException catch (e) {
      if (gen != _gen) return;
      error = e.message;
    } finally {
      if (gen == _gen) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final gen = _gen;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await repo.getList(status: statusFilter, page: _page + 1, pageSize: pageSize);
      if (gen != _gen) return;
      sessions = [...sessions, ...page.data];
      _page = page.page;
      _totalPages = page.totalPages;
    } on ApiException {
      // biarkan daftar yang ada
    } finally {
      if (gen == _gen) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }
}
