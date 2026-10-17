import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/consignment_provider.dart';

/// Sisa stok fisik barang titipan di tiap outlet (satuan dasar).
class OutletStockScreen extends StatefulWidget {
  const OutletStockScreen({super.key});

  @override
  State<OutletStockScreen> createState() => _OutletStockScreenState();
}

class _OutletStockScreenState extends State<OutletStockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ConsignmentProvider>().loadOutletStock();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ConsignmentProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sisa Stok di Outlet'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Muat ulang', onPressed: prov.loadOutletStock)],
      ),
      body: SafeArea(child: _buildBody(prov)),
    );
  }

  Widget _buildBody(ConsignmentProvider prov) {
    if (prov.outletLoading && prov.outletStock.isEmpty) return const Center(child: CircularProgressIndicator());
    if (prov.outletError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(prov.outletError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: prov.loadOutletStock, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }
    if (prov.outletStock.isEmpty) {
      return const Center(child: Text('Tidak ada barang titipan di outlet', style: TextStyle(color: AppColors.muted)));
    }

    return RefreshIndicator(
      onRefresh: prov.loadOutletStock,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: prov.outletStock.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final outlet = prov.outletStock[i];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(outlet.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final p in outlet.products)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(p.sku != null && p.sku!.isNotEmpty ? '${p.name} (${p.sku})' : p.name, style: const TextStyle(fontSize: 13.5)),
                          ),
                          Text('${p.quantity} ${p.unit}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        ],
                      ),
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
