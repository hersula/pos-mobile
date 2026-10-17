import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../data/models/consignment.dart';
import '../data/repositories/consignment_repository.dart';

/// State daftar konsinyasi (filter status) dan sisa stok di outlet.
/// Aksi tulis dilakukan layar lewat [repo]; setelah itu [load] dipanggil ulang.
class ConsignmentProvider extends ChangeNotifier {
  ConsignmentProvider({ConsignmentRepository? repo}) : repo = repo ?? ConsignmentRepository();

  final ConsignmentRepository repo;

  List<ConsignmentOrder> orders = [];
  String? statusFilter; // null = semua
  bool loading = false;
  String? error;

  List<OutletStock> outletStock = [];
  bool outletLoading = false;
  String? outletError;

  static const int pageSize = 20;
  int _page = 1;
  int _totalPages = 1;
  bool loadingMore = false;
  int _gen = 0; // mencegah respons lama menimpa filter baru

  bool get hasMore => _page < _totalPages;

  Future<void> load() async {
    final gen = ++_gen;
    loading = true;
    loadingMore = false;
    error = null;
    notifyListeners();
    try {
      final page = await repo.getConsignments(status: statusFilter, page: 1, pageSize: pageSize);
      if (gen != _gen) return;
      orders = page.data;
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

  /// Muat halaman berikutnya (infinite scroll); error ditampilkan lewat [error] hanya bila daftar kosong.
  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore) return;
    final gen = _gen;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await repo.getConsignments(status: statusFilter, page: _page + 1, pageSize: pageSize);
      if (gen != _gen) return;
      orders = [...orders, ...page.data];
      _page = page.page;
      _totalPages = page.totalPages;
    } on ApiException {
      // biarkan daftar yang sudah ada; pengguna bisa scroll lagi untuk mencoba ulang
    } finally {
      if (gen == _gen) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> setStatusFilter(String? status) async {
    statusFilter = status;
    await load();
  }

  Future<void> loadOutletStock() async {
    outletLoading = true;
    outletError = null;
    notifyListeners();
    try {
      outletStock = await repo.getOutletStock();
    } on ApiException catch (e) {
      outletError = e.message;
    } finally {
      outletLoading = false;
      notifyListeners();
    }
  }
}
