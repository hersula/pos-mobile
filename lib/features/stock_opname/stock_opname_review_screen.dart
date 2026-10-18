import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/stock_opname.dart';
import '../../data/repositories/stock_opname_repository.dart';
import '../../state/auth_provider.dart';
import 'stock_opname_detail_screen.dart';
import 'stock_opname_widgets.dart';

enum _ReviewFilter { all, surplus, shortage }

class StockOpnameReviewScreen extends StatefulWidget {
  final String opnameId;
  const StockOpnameReviewScreen({super.key, required this.opnameId});

  @override
  State<StockOpnameReviewScreen> createState() => _StockOpnameReviewScreenState();
}

class _StockOpnameReviewScreenState extends State<StockOpnameReviewScreen> {
  final _repo = StockOpnameRepository();
  StockOpname? _opname;
  bool _loading = true;
  String? _loadError;
  bool _processing = false;
  String? _error;
  _ReviewFilter _filter = _ReviewFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
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
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndFinalize() async {
    final o = _opname!;
    final diffItems = o.items.where((i) => i.counted && i.diff != 0).length;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Finalisasi & Sesuaikan Stok', style: TextStyle(fontFamily: 'Archivo', fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('$diffItems produk akan disesuaikan.'),
              Text('Selisih bersih: ${signedRupiah(o.summary.netValue)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const OpnameBanner(
                kind: BannerKind.danger,
                text: 'Stok sistem akan dikoreksi dan dicatat sebagai penyesuaian. Sesi tidak dapat diubah lagi.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kembali'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ya, Finalisasi'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await _finalize(clampToZero: false);
  }

  Future<void> _finalize({required bool clampToZero}) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final r = await _repo.finalize(widget.opnameId, clampToZero: clampToZero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opname selesai. Stok disesuaikan untuk ${r.adjustedItems} produk.')));
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => StockOpnameDetailScreen(opnameId: widget.opnameId)));
    } on StockConflictException catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      final clamp = await _showConflict(e);
      if (clamp == true && mounted) await _finalize(clampToZero: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = switch (apiErrorCode(e)) {
          'NO_COUNTED_ITEMS' => 'Belum ada produk yang dihitung. Isi minimal satu hitungan.',
          'INVALID_STATUS' => 'Sesi sudah tidak berstatus Draft.',
          _ => 'Gagal finalisasi: ${e.message}. Sesi tetap Draft.',
        };
      });
    }
  }

  Future<bool?> _showConflict(StockConflictException e) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok berubah sejak snapshot'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Penyesuaian membuat stok negatif untuk produk berikut. Tidak ada perubahan yang disimpan.'),
              const SizedBox(height: 8),
              for (final it in e.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('${it.productName}: stok saat ini ${fmtQty(it.currentQty)}, selisih ${signedQty(it.diff)}',
                      style: const TextStyle(fontSize: 12.5)),
                ),
              const SizedBox(height: 8),
              const Text('Lanjutkan dengan menahan stok produk tersebut di 0?', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalisasi, Tahan di 0'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = context.watch<AuthProvider>().currentUser?.canManageStockOpname ?? false;
    final o = _opname;
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Review Selisih')),
        body: SafeArea(child: _body(o)),
        bottomNavigationBar: o == null
            ? null
            : canManage
                ? BottomActionBar(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _processing ? null : _confirmAndFinalize,
                        child: Text(_processing ? 'Memproses...' : 'Finalisasi & Sesuaikan Stok'),
                      ),
                    ),
                  ])
                : const BottomActionBar(children: [
                    Expanded(
                      child: Text('Hanya Owner/Manager yang dapat melakukan finalisasi.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    ),
                  ]),
      ),
    );
  }

  Widget _body(StockOpname? o) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null || o == null) {
      return OpnameErrorView(title: 'Gagal memuat review', message: _loadError, onRetry: _load);
    }
    final counted = o.items.where((i) => i.counted).toList();
    final matched = counted.where((i) => i.diff == 0).length;
    final uncounted = o.items.length - counted.length;
    final diffs = counted.where((i) => i.diff != 0).where((i) {
      switch (_filter) {
        case _ReviewFilter.all:
          return true;
        case _ReviewFilter.surplus:
          return i.diff! > 0;
        case _ReviewFilter.shortage:
          return i.diff! < 0;
      }
    }).toList();
    final s = o.summary;
    final net = s.netValue;

    return CenteredColumn(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: SummaryBox(label: 'Lebih', value: signedRupiah(s.surplusValue), color: AppColors.info)),
              const SizedBox(width: 8),
              Expanded(child: SummaryBox(label: 'Kurang', value: signedRupiah(-s.shortageValue), color: AppColors.danger)),
              const SizedBox(width: 8),
              Expanded(child: SummaryBox(label: 'Selisih bersih', value: signedRupiah(net), color: diffColor(net))),
            ],
          ),
          if (uncounted > 0) ...[
            const SizedBox(height: 12),
            OpnameBanner(kind: BannerKind.pending, text: '$uncounted produk belum dihitung dan tidak akan diubah saat finalisasi.'),
          ],
          if (o.items.any((i) => i.stockChanged)) ...[
            const SizedBox(height: 12),
            const OpnameBanner(
              kind: BannerKind.info,
              text: 'Stok sebagian produk berubah sejak snapshot (penjualan/pembelian). Finalisasi menerapkan selisih relatif ke stok saat ini.',
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 12), OpnameBanner(kind: BannerKind.danger, text: _error!)],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in {
                  _ReviewFilter.all: 'Semua selisih',
                  _ReviewFilter.surplus: 'Lebih',
                  _ReviewFilter.shortage: 'Kurang',
                }.entries) ...[
                  opnameChip(label: e.value, selected: _filter == e.key, color: AppColors.accent, onTap: () => setState(() => _filter = e.key)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (counted.isNotEmpty && counted.every((i) => i.diff == 0))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Semua stok cocok', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600))),
            )
          else if (counted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada produk yang dihitung', style: TextStyle(color: AppColors.muted))),
            )
          else
            for (final it in diffs) ...[DiffRow(item: it), const SizedBox(height: 8)],
          if (matched > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$matched produk cocok tidak ditampilkan', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}
