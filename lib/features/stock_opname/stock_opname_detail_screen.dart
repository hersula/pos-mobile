import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/stock_opname.dart';
import '../../data/repositories/stock_opname_repository.dart';
import '../../state/auth_provider.dart';
import 'stock_opname_cancel.dart';
import 'stock_opname_count_screen.dart';
import 'stock_opname_widgets.dart';

class StockOpnameDetailScreen extends StatefulWidget {
  final String opnameId;
  const StockOpnameDetailScreen({super.key, required this.opnameId});

  @override
  State<StockOpnameDetailScreen> createState() => _StockOpnameDetailScreenState();
}

class _StockOpnameDetailScreenState extends State<StockOpnameDetailScreen> {
  final _repo = StockOpnameRepository();
  StockOpname? _opname;
  bool _loading = true;
  String? _error;
  bool _showAll = false;

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
      final o = await _repo.getDetail(widget.opnameId);
      if (!mounted) return;
      setState(() {
        _opname = o;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404 ? 'Sesi tidak ditemukan.' : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    if (await confirmCancelOpname(context, widget.opnameId, _repo) && mounted) _load();
  }

  Future<void> _continue() async {
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => StockOpnameCountScreen(opnameId: widget.opnameId)));
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<AuthProvider>().currentUser?.canManageStockOpname ?? false;
    final canCount = context.watch<AuthProvider>().currentUser?.canCountStockOpname ?? false;
    final o = _opname;
    return Scaffold(
      appBar: AppBar(title: Text(o?.opnameNo ?? 'Detail Sesi')),
      body: SafeArea(child: _body(o)),
      bottomNavigationBar: (o != null && o.isDraft && canCount)
          ? BottomActionBar(children: [
              if (canManage) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: _cancel,
                    child: const Text('Batalkan Sesi'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: FilledButton(onPressed: _continue, child: const Text('Lanjut Hitung'))),
            ])
          : null,
    );
  }

  Widget _meta(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.muted)),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]), style: const TextStyle(fontSize: 12.5)),
      );

  Widget _body(StockOpname? o) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || o == null) {
      return OpnameErrorView(title: 'Gagal memuat detail sesi', message: _error, onRetry: _load);
    }
    final cancelled = o.status == 'CANCELLED';
    final s = o.summary;
    final diffCount = o.items.where((i) => i.counted && i.diff != 0).length;
    final rows = o.items.where((i) => _showAll ? true : (i.counted && i.diff != 0)).toList();

    return CenteredColumn(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(o.warehouseName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                      Text(o.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: opnameStatusColor(o.status))),
                    ],
                  ),
                  _meta('Kategori', o.categoryId == null ? 'Semua kategori' : 'Satu kategori'),
                  if (o.createdAt != null) _meta('Dibuat', DateFormatter.dateTime(o.createdAt!)),
                  if (o.completedAt != null) _meta(cancelled ? 'Dibatalkan' : 'Difinalisasi', DateFormatter.dateTime(o.completedAt!)),
                  if (o.note != null && o.note!.isNotEmpty) _meta('Catatan', o.note!),
                  if (cancelled && (o.cancelReason ?? '').isNotEmpty) _meta('Alasan batal', o.cancelReason!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SummaryBox(label: 'Dihitung', value: '${s.countedItems}/${s.totalItems}', color: cancelled ? AppColors.muted : AppColors.text)),
              const SizedBox(width: 8),
              Expanded(child: SummaryBox(label: 'Selisih', value: '$diffCount produk', color: cancelled ? AppColors.muted : AppColors.text)),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryBox(
                  label: 'Nilai selisih',
                  value: signedRupiah(s.netValue),
                  color: diffColor(s.netValue, muted: cancelled),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              opnameChip(label: 'Selisih', selected: !_showAll, color: AppColors.accent, onTap: () => setState(() => _showAll = false)),
              const SizedBox(width: 8),
              opnameChip(label: 'Semua', selected: _showAll, color: AppColors.accent, onTap: () => setState(() => _showAll = true)),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Tidak ada selisih', style: TextStyle(color: AppColors.muted))),
            )
          else
            for (final it in rows) ...[DiffRow(item: it, mutedColors: cancelled), const SizedBox(height: 8)],
        ],
      ),
    );
  }
}
