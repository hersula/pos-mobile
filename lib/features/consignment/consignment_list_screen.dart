import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/consignment.dart';
import '../../state/auth_provider.dart';
import '../../state/consignment_provider.dart';
import 'consignment_detail_screen.dart';
import 'consignment_form_screen.dart';
import 'outlet_stock_screen.dart';

const kConsignmentStatusColors = {
  'DRAFT': AppColors.muted,
  'SENT': AppColors.info,
  'PARTIALLY_SETTLED': AppColors.pending,
  'SETTLED': AppColors.accent,
  'CANCELLED': AppColors.danger,
};

class ConsignmentListScreen extends StatefulWidget {
  const ConsignmentListScreen({super.key});

  @override
  State<ConsignmentListScreen> createState() => _ConsignmentListScreenState();
}

class _ConsignmentListScreenState extends State<ConsignmentListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConsignmentProvider>().load();
    });
  }

  Future<void> _openDetail(ConsignmentOrder o) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ConsignmentDetailScreen(consignmentId: o.id)),
    );
    if (mounted) context.read<ConsignmentProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = context.watch<AuthProvider>().currentUser?.canWriteConsignment ?? false;
    final prov = context.watch<ConsignmentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konsinyasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Sisa Stok di Outlet',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OutletStockScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Muat ulang', onPressed: prov.load),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ConsignmentFormScreen()),
                );
                if (created == true && mounted) context.read<ConsignmentProvider>().load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Konsinyasi'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _chip(prov, 'Semua', null),
                  for (final e in kConsignmentStatusLabels.entries) ...[
                    const SizedBox(width: 8),
                    _chip(prov, e.value, e.key),
                  ],
                ],
              ),
            ),
            Expanded(child: _buildBody(prov)),
          ],
        ),
      ),
    );
  }

  Widget _chip(ConsignmentProvider prov, String label, String? value) {
    final selected = prov.statusFilter == value;
    final color = value != null ? (kConsignmentStatusColors[value] ?? AppColors.accent) : AppColors.accent;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter $label',
      child: GestureDetector(
        onTap: () => prov.setStatusFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? color : AppColors.line),
          ),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? color : AppColors.muted)),
        ),
      ),
    );
  }

  Widget _buildBody(ConsignmentProvider prov) {
    if (prov.loading && prov.orders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (prov.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(prov.error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: prov.load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (prov.orders.isEmpty) {
      return const Center(child: Text('Belum ada konsinyasi', style: TextStyle(color: AppColors.muted)));
    }

    return RefreshIndicator(
      onRefresh: prov.load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 200) prov.loadMore();
          return false;
        },
        child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: prov.orders.length + (prov.loadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= prov.orders.length) {
            return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
          }
          final o = prov.orders[i];
          final color = kConsignmentStatusColors[o.status] ?? AppColors.muted;
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => _openDetail(o),
              title: Text(o.consignmentNo, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${o.customerName}${o.createdAt != null ? ' · ${DateFormatter.short(o.createdAt!)}' : ''}\nSisa di outlet: ${CurrencyFormatter.format(o.summary.totalValueRemaining)}',
                style: const TextStyle(fontSize: 12),
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.format(o.summary.totalValueSent), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(o.statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
