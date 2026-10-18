import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/stock_opname.dart';
import '../../data/repositories/stock_opname_repository.dart';
import '../../state/auth_provider.dart';
import '../common/barcode_scanner_screen.dart';
import 'stock_opname_detail_screen.dart';
import 'stock_opname_review_screen.dart';
import 'stock_opname_widgets.dart';
import 'stock_opname_cancel.dart';

enum _CountFilter { all, uncounted, diff }

/// Layar hitung fisik untuk sesi DRAFT.
class StockOpnameCountScreen extends StatefulWidget {
  final String opnameId;
  const StockOpnameCountScreen({super.key, required this.opnameId});

  @override
  State<StockOpnameCountScreen> createState() => _StockOpnameCountScreenState();
}

class _StockOpnameCountScreenState extends State<StockOpnameCountScreen> {
  static const double _rowExtent = 148;

  final _repo = StockOpnameRepository();
  final _scroll = ScrollController();
  final _controllers = <String, TextEditingController>{};
  final _focus = <String, FocusNode>{};

  StockOpname? _opname;
  final Map<String, num?> _counts = {}; // nilai di layar
  final Map<String, num?> _saved = {}; // nilai di server
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  String? _saveError;
  String? _scanError;
  String _search = '';
  _CountFilter _filter = _CountFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _dirty => _counts.keys.any((k) => _counts[k] != _saved[k]);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final o = await _repo.getDetail(widget.opnameId);
      if (!mounted) return;
      if (!o.isDraft) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => StockOpnameDetailScreen(opnameId: o.id)));
        return;
      }
      setState(() {
        _opname = o;
        for (final it in o.items) {
          // Hitungan lokal yang belum tersimpan dipertahankan saat muat ulang.
          final keepLocal =
              _counts.containsKey(it.id) && _counts[it.id] != _saved[it.id];
          _saved[it.id] = it.countedQty;
          if (!keepLocal) {
            _counts[it.id] = it.countedQty;
            _controllerFor(it.id).text =
                it.countedQty == null ? '' : fmtQty(it.countedQty!);
          }
        }
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

  TextEditingController _controllerFor(String id) =>
      _controllers.putIfAbsent(id, () => TextEditingController());
  FocusNode _focusFor(String id) => _focus.putIfAbsent(id, () => FocusNode());

  void _setCount(String id, num? v, {bool updateText = true}) {
    setState(() {
      _counts[id] = v;
      _saveError = null;
    });
    if (updateText) {
      final c = _controllerFor(id);
      final t = v == null ? '' : fmtQty(v);
      c.value = TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: t.length));
    }
  }

  void _step(OpnameItem it, int delta) {
    final cur = _counts[it.id];
    num next;
    if (cur == null) {
      next = delta > 0 ? 1 : 0; // kolom kosong mulai dari 0 lalu +1
    } else {
      next = cur + delta;
    }
    if (next < 0) next = 0;
    if (next > kMaxOpnameQty) next = kMaxOpnameQty;
    _setCount(it.id, next);
  }

  /// Pesan untuk 400: tunjuk produk bermasalah bila respons memuat itemId.
  String _badRequestMessage(ApiException e) {
    final names = <String>{};
    final details = e.data?['details'];
    final raw =
        details is Map ? (details['items'] ?? details['errors']) : details;
    if (raw is List) {
      for (final d in raw) {
        if (d is! Map) continue;
        var id = d['itemId']?.toString();
        if (id == null) {
          // path gaya "items.3.countedQty" -> indeks elemen batch (urutan map changed)
          final path = d['path'] ?? d['field'];
          final m =
              RegExp(r'items[.\[](\d+)').firstMatch(path?.toString() ?? '');
          final idx = m == null ? null : int.tryParse(m.group(1)!);
          if (idx != null && idx < _lastBatchIds.length)
            id = _lastBatchIds[idx];
        }
        if (id == null) continue;
        for (final it in _opname?.items ?? const <OpnameItem>[]) {
          if (it.id == id) names.add(it.name);
        }
      }
    }
    if (names.isNotEmpty) {
      return 'Hitungan tidak valid untuk: ${names.join(', ')}. Periksa jumlahnya (0 sampai 2.000.000.000) lalu simpan lagi.';
    }
    return 'Hitungan ditolak server karena ada nilai tidak valid (harus bilangan bulat 0 sampai 2.000.000.000). Periksa jumlah yang baru diubah. ${e.message}';
  }

  List<String> _lastBatchIds = const [];

  Future<bool> _save({bool silent = false}) async {
    final o = _opname;
    if (o == null) return false;
    final changed = <String, num?>{
      for (final k in _counts.keys)
        if (_counts[k] != _saved[k]) k: _counts[k],
    };
    if (changed.isEmpty) return true;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final entries = changed.entries.toList();
      for (var i = 0; i < entries.length; i += 500) {
        final chunk = Map<String, num?>.fromEntries(entries.skip(i).take(500));
        _lastBatchIds = chunk.keys.toList();
        await _repo.saveCounts(o.id, chunk);
        _saved.addAll(chunk);
      }
      if (!mounted) return true;
      setState(() => _saving = false);
      if (!silent)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft tersimpan')));
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _saveError = switch (e.statusCode) {
          409 => 'Sesi sudah tidak berstatus Draft. ${e.message}',
          400 => _badRequestMessage(e),
          _ => 'Gagal menyimpan: ${e.message}',
        };
      });
      return false;
    }
  }

  Future<void> _review() async {
    if (!await _save(silent: true) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StockOpnameReviewScreen(opnameId: widget.opnameId)));
    if (mounted) _load();
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final o = _opname;
    if (o == null) return;
    final lc = code.trim().toLowerCase();
    final matches = o.items.where((i) =>
        (i.barcode ?? '').toLowerCase() == lc ||
        (i.sku ?? '').toLowerCase() == lc);
    if (matches.isEmpty) {
      setState(() => _scanError = 'Barcode $code tidak ada di sesi ini');
      return;
    }
    HapticFeedback.mediumImpact();
    final it = matches.first;
    setState(() {
      _scanError = null;
      _search = '';
      _filter = _CountFilter.all;
    });
    final index = o.items.indexOf(it);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        (index * _rowExtent)
            .clamp(0, _scroll.position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusFor(it.id).requestFocus();
    });
  }

  List<OpnameItem> _visible(StockOpname o) {
    final q = _search.trim().toLowerCase();
    return o.items.where((it) {
      if (q.isNotEmpty) {
        final hit = it.name.toLowerCase().contains(q) ||
            (it.sku ?? '').toLowerCase().contains(q) ||
            (it.barcode ?? '').toLowerCase().contains(q);
        if (!hit) return false;
      }
      final c = _counts[it.id];
      switch (_filter) {
        case _CountFilter.all:
          return true;
        case _CountFilter.uncounted:
          return c == null;
        case _CountFilter.diff:
          return c != null && c != it.systemQty;
      }
    }).toList();
  }

  Future<void> _cancelSession() async {
    final ok = await confirmCancelOpname(context, widget.opnameId, _repo);
    if (ok && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => StockOpnameDetailScreen(opnameId: widget.opnameId)));
    }
  }

  Future<bool> _confirmLeave() async {
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan hitungan?'),
        content: const Text('Ada hitungan yang belum disimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Buang')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Simpan Draft')),
        ],
      ),
    );
    if (res == 'discard') return true;
    if (res == 'save') return _save(silent: true);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canCount = user?.canCountStockOpname ?? false;
    final canManage = user?.canManageStockOpname ?? false;
    final o = _opname;

    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_saving) return;
        if (await _confirmLeave() && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(o?.opnameNo ?? 'Hitung Stok'),
          actions: [
            if (o != null && canCount)
              IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan barcode',
                  onPressed: _scan),
            if (o != null)
              PopupMenuButton<String>(
                tooltip: 'Menu lainnya',
                onSelected: (v) => v == 'review' ? _review() : _cancelSession(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'review', child: Text('Review Selisih')),
                  if (canManage)
                    const PopupMenuItem(
                        value: 'cancel', child: Text('Batalkan Sesi')),
                ],
              ),
          ],
        ),
        body: SafeArea(child: _body(o, canCount)),
        bottomNavigationBar: o == null
            ? null
            : BottomActionBar(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: (_saving || !canCount) ? null : _save,
                      child: const Text('Simpan Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : (canCount ? _review : null),
                      child: Text(_saving ? 'Menyimpan...' : 'Review Selisih'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _body(StockOpname? o, bool canCount) {
    if (_loading && o == null)
      return const Center(child: CircularProgressIndicator());
    if (_loadError != null && o == null) {
      return OpnameErrorView(
          title: 'Gagal memuat sesi', message: _loadError, onRetry: _load);
    }
    if (o == null) return const SizedBox.shrink();

    final total = o.items.length;
    final counted = o.items.where((i) => _counts[i.id] != null).length;
    final items = _visible(o);

    return CenteredColumn(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                  hintText: 'Cari nama, SKU, atau barcode...',
                  prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$counted / $total sudah dihitung',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : counted / total,
                    minHeight: 6,
                    color: AppColors.accent,
                    backgroundColor: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          if (_scanError != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child:
                    OpnameBanner(kind: BannerKind.danger, text: _scanError!)),
          if (_saveError != null)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child:
                    OpnameBanner(kind: BannerKind.danger, text: _saveError!)),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OpnameBanner(
                kind: BannerKind.danger,
                text: 'Gagal memuat ulang. Hitungan di layar aman.',
                action: TextButton(
                    onPressed: _load, child: const Text('Coba Lagi')),
              ),
            ),
          if (!canCount)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OpnameBanner(
                  kind: BannerKind.info,
                  text: 'Peran Anda tidak dapat mengisi hitungan.'),
            ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in {
                  _CountFilter.all: 'Semua',
                  _CountFilter.uncounted: 'Belum dihitung',
                  _CountFilter.diff: 'Selisih',
                }.entries) ...[
                  opnameChip(
                      label: e.value,
                      selected: _filter == e.key,
                      color: AppColors.accent,
                      onTap: () => setState(() => _filter = e.key)),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('Tidak ada produk yang cocok',
                        style: TextStyle(color: AppColors.muted)))
                : ListView.builder(
                    controller: _scroll,
                    itemExtent: _rowExtent,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: items.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CountRow(
                        key: ValueKey(items[i].id),
                        item: items[i],
                        controller: _controllerFor(items[i].id),
                        focusNode: _focusFor(items[i].id),
                        count: _counts[items[i].id],
                        enabled: canCount && !_saving,
                        onChanged: (v) =>
                            _setCount(items[i].id, v, updateText: false),
                        onStep: (d) => _step(items[i], d),
                        onSubmitted: () {
                          if (i + 1 < items.length)
                            _focusFor(items[i + 1].id).requestFocus();
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final OpnameItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final num? count;
  final bool enabled;
  final ValueChanged<num?> onChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onSubmitted;

  const _CountRow({
    super.key,
    required this.item,
    required this.controller,
    required this.focusNode,
    required this.count,
    required this.enabled,
    required this.onChanged,
    required this.onStep,
    required this.onSubmitted,
  });

  Widget _stepBtn(IconData icon, String label, int delta) {
    return Semantics(
      button: true,
      label: '$label ${item.name}',
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: AppColors.line, width: 1.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: enabled ? () => onStep(delta) : null,
          child: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diff = count == null ? null : count! - item.systemQty;
    final sub = [
      if (item.sku != null) item.sku!,
      if (item.unit.isNotEmpty) item.unit
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Stok sistem',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text(fmtQty(item.systemQty),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _stepBtn(Icons.remove_rounded, 'Kurangi', -1),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  height: 48,
                  child: Semantics(
                    label: 'Jumlah fisik ${item.name}',
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        const _MaxQtyFormatter()
                      ],
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                      decoration: const InputDecoration(
                          hintText: '-',
                          contentPadding: EdgeInsets.symmetric(horizontal: 4)),
                      onChanged: (t) =>
                          onChanged(t.isEmpty ? null : int.tryParse(t)),
                      onSubmitted: (_) => onSubmitted(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _stepBtn(Icons.add_rounded, 'Tambah', 1),
                const Spacer(),
                DiffTag(diff: diff),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Batas atas hitungan fisik sesuai kontrak API.
const int kMaxOpnameQty = 2000000000;

class _MaxQtyFormatter extends TextInputFormatter {
  const _MaxQtyFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final n = int.tryParse(newValue.text);
    return (n != null && n > kMaxOpnameQty) ? oldValue : newValue;
  }
}
