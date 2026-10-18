import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/stock_opname.dart';
import '../../state/auth_provider.dart';
import '../../state/stock_opname_provider.dart';
import 'stock_opname_count_screen.dart';
import 'stock_opname_detail_screen.dart';
import 'stock_opname_form_screen.dart';
import 'stock_opname_widgets.dart';

class StockOpnameListScreen extends StatefulWidget {
  const StockOpnameListScreen({super.key});

  @override
  State<StockOpnameListScreen> createState() => _StockOpnameListScreenState();
}

class _StockOpnameListScreenState extends State<StockOpnameListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StockOpnameProvider>().load();
    });
  }

  Future<void> _open(StockOpname s) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => s.isDraft ? StockOpnameCountScreen(opnameId: s.id) : StockOpnameDetailScreen(opnameId: s.id),
    ));
    if (mounted) context.read<StockOpnameProvider>().load();
  }

  Future<void> _create() async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const StockOpnameFormScreen()));
    if (mounted) context.read<StockOpnameProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = context.watch<AuthProvider>().currentUser?.canManageStockOpname ?? false;
    final prov = context.watch<StockOpnameProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Opname'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Muat ulang', onPressed: prov.load)],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Sesi Opname'),
            )
          : null,
      body: SafeArea(
        child: CenteredColumn(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: prov.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Cari nomor sesi atau gudang...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              if (!canWrite)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: OpnameBanner(
                    kind: BannerKind.info,
                    text: 'Anda dapat melihat sesi dan mengisi hitungan. Membuat, finalisasi, dan pembatalan hanya untuk Owner/Manager.',
                  ),
                ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    opnameChip(
                        label: 'Semua', selected: prov.statusFilter == null, color: AppColors.accent, onTap: () => prov.setStatusFilter(null)),
                    for (final e in kOpnameStatusLabels.entries) ...[
                      const SizedBox(width: 8),
                      opnameChip(
                        label: e.value,
                        selected: prov.statusFilter == e.key,
                        color: opnameStatusColor(e.key),
                        onTap: () => prov.setStatusFilter(e.key),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: _body(prov, canWrite)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(StockOpnameProvider prov, bool canWrite) {
    if (prov.loading && prov.sessions.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 72,
          decoration: BoxDecoration(color: AppColors.line.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
    if (prov.error != null && prov.sessions.isEmpty) {
      return OpnameErrorView(title: 'Gagal memuat sesi opname', message: prov.error, onRetry: prov.load);
    }
    final items = prov.filtered;
    if (items.isEmpty) {
      final filtering = prov.statusFilter != null || prov.search.trim().isNotEmpty;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(filtering ? 'Tidak ada sesi yang cocok' : 'Belum ada sesi opname',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                filtering
                    ? 'Ubah kata kunci atau filter status.'
                    : 'Buat sesi untuk mencocokkan stok sistem dengan hitungan fisik di gudang.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
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
          itemCount: items.length + (prov.loadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            if (i >= items.length) {
              return const Center(
                  child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
            }
            return _SessionCard(session: items[i], onTap: () => _open(items[i]));
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final StockOpname session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = session;
    final color = opnameStatusColor(s.status);
    final diffItems = s.summary.surplusQty != 0 || s.summary.shortageQty != 0;
    final String right;
    switch (s.status) {
      case 'DRAFT':
        right = s.summary.countedItems == 0 ? 'Belum dihitung' : '${s.summary.countedItems}/${s.summary.totalItems} dihitung';
        break;
      case 'COMPLETED':
        right = signedRupiah(s.summary.netValue);
        break;
      default:
        right = '-';
    }
    final parts = [
      s.warehouseName,
      s.categoryId == null ? 'Semua kategori' : 'Satu kategori',
      if (s.createdAt != null) DateFormatter.short(s.createdAt!),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Semantics(
      button: true,
      label: 'Sesi ${s.opnameNo}, ${s.statusLabel}',
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.opnameNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(parts, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(right,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: s.status == 'COMPLETED' && diffItems ? diffColor(s.summary.netValue) : AppColors.text)),
                      const SizedBox(height: 2),
                      Text(s.statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
