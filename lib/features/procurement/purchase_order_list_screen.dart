import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/purchase_order.dart';
import '../../data/repositories/purchase_order_repository.dart';
import 'purchase_order_detail_screen.dart';
import 'purchase_order_form_screen.dart';
import 'supplier_list_screen.dart';

const _statusLabels = {
  'DRAFT': 'Menunggu Diterima',
  'RECEIVED': 'Sudah Diterima',
  'CANCELLED': 'Dibatalkan',
};

const _statusColors = {
  'DRAFT': AppColors.pending,
  'RECEIVED': AppColors.accent,
  'CANCELLED': AppColors.danger,
};

class PurchaseOrderListScreen extends StatefulWidget {
  const PurchaseOrderListScreen({super.key});

  @override
  State<PurchaseOrderListScreen> createState() => _PurchaseOrderListScreenState();
}

class _PurchaseOrderListScreenState extends State<PurchaseOrderListScreen> {
  final _repo = PurchaseOrderRepository();
  List<PurchaseOrder> _orders = [];
  String? _statusFilter; // null = semua
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _repo.getPurchaseOrders(status: _statusFilter);
      if (mounted) setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengadaan Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Kelola Supplier',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupplierListScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const PurchaseOrderFormScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('PO Baru'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _chip('Semua', null),
                  const SizedBox(width: 8),
                  _chip('Menunggu Diterima', 'DRAFT'),
                  const SizedBox(width: 8),
                  _chip('Sudah Diterima', 'RECEIVED'),
                  const SizedBox(width: 8),
                  _chip('Dibatalkan', 'CANCELLED'),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _statusFilter == value;
    final color = value != null ? (_statusColors[value] ?? AppColors.accent) : AppColors.accent;
    return GestureDetector(
      onTap: () {
        setState(() => _statusFilter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.line),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? color : AppColors.muted)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(child: Text('Belum ada pengadaan barang', style: TextStyle(color: AppColors.muted)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final po = _orders[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () async {
                final changed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: po.id)),
                );
                if (changed == true) _load();
              },
              title: Text(po.poNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${po.supplier?.name ?? "Tanpa supplier"} · ${DateFormatter.short(po.createdAt)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(po.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    _statusLabels[po.status] ?? po.status,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _statusColors[po.status] ?? AppColors.muted),
                  ),
                  if (po.status == 'RECEIVED' && po.isCreditPurchase && !po.isDebtSettled)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text('Ada Hutang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.danger)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
