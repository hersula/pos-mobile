import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/auth_provider.dart';

const _paymentMethodLabels = {
  'CASH': 'Tunai',
  'DEBIT': 'Kartu Debit',
  'CREDIT': 'Kartu Kredit',
  'QRIS': 'QRIS',
  'TRANSFER': 'Transfer',
  'EWALLET': 'E-Wallet',
};

const _purchasePaymentMethodLabels = {
  'CASH': 'Tunai',
  'CREDIT': 'Tempo',
  'TRANSFER': 'Transfer Bank',
};

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _canViewAccounting;
  late bool _canViewPurchases;
  late int _tabCount;

  final _reportRepo = ReportRepository();

  DateTime _selectedDate = DateTime.now();
  SalesSummary? _summary;
  bool _loadingSummary = true;
  String? _summaryError;

  DateTime _plFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _plTo = DateTime.now();
  ProfitLossReport? _profitLoss;
  bool _loadingPl = false;
  String? _plError;

  DateTime _purchaseFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _purchaseTo = DateTime.now();
  PurchasesSummary? _purchasesSummary;
  bool _loadingPurchases = false;
  String? _purchasesError;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _canViewAccounting = user?.canViewAccounting ?? false;
    _canViewPurchases = (user?.canManageInventory ?? false) || _canViewAccounting;
    _tabCount = 1 + (_canViewAccounting ? 1 : 0) + (_canViewPurchases ? 1 : 0);

    _tabController = TabController(length: _tabCount, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Index tab: 0 = Tutup Kasir (selalu ada), lalu Laba Rugi & Pembelian menyusul sesuai hak akses
  int get _profitLossTabIndex => _canViewAccounting ? 1 : -1;
  int get _purchasesTabIndex => _canViewPurchases ? (1 + (_canViewAccounting ? 1 : 0)) : -1;

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await _reportRepo.getSalesSummary(dateFrom: _ymd(_selectedDate), dateTo: _ymd(_selectedDate));
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadProfitLoss() async {
    setState(() {
      _loadingPl = true;
      _plError = null;
    });
    try {
      final report = await _reportRepo.getProfitLoss(dateFrom: _ymd(_plFrom), dateTo: _ymd(_plTo));
      if (mounted) setState(() => _profitLoss = report);
    } on ApiException catch (e) {
      if (mounted) setState(() => _plError = e.message);
    } finally {
      if (mounted) setState(() => _loadingPl = false);
    }
  }

  Future<void> _loadPurchasesSummary() async {
    setState(() {
      _loadingPurchases = true;
      _purchasesError = null;
    });
    try {
      final report = await _reportRepo.getPurchasesSummary(dateFrom: _ymd(_purchaseFrom), dateTo: _ymd(_purchaseTo));
      if (mounted) setState(() => _purchasesSummary = report);
    } on ApiException catch (e) {
      if (mounted) setState(() => _purchasesError = e.message);
    } finally {
      if (mounted) setState(() => _loadingPurchases = false);
    }
  }

  /// Dipanggil dari [DashboardScreen] setiap kali kasir/owner pindah ke tab
  /// Laporan, supaya angkanya selalu segar tanpa perlu tarik-refresh manual.
  /// Tab "Tutup Kasir" selalu di-refresh (murah & selalu jadi tab default),
  /// sedangkan tab Laba Rugi/Pembelian cuma di-refresh kalau sebelumnya
  /// sudah pernah dibuka (hemat request kalau belum pernah disentuh sama sekali).
  Future<void> refreshActiveTab() async {
    final futures = <Future<void>>[_loadSummary()];
    if (_profitLoss != null) futures.add(_loadProfitLoss());
    if (_purchasesSummary != null) futures.add(_loadPurchasesSummary());
    await Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[const Tab(text: 'Tutup Kasir')];
    final views = <Widget>[_buildSummaryTab()];

    if (_canViewAccounting) {
      tabs.add(const Tab(text: 'Laba Rugi'));
      views.add(_buildProfitLossTab());
    }
    if (_canViewPurchases) {
      tabs.add(const Tab(text: 'Pembelian'));
      views.add(_buildPurchasesTab());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: _tabCount > 1
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.ink,
                indicatorColor: AppColors.accent,
                isScrollable: _tabCount > 2,
                onTap: (i) {
                  if (i == _profitLossTabIndex && _profitLoss == null) _loadProfitLoss();
                  if (i == _purchasesTabIndex && _purchasesSummary == null) _loadPurchasesSummary();
                },
                tabs: tabs,
              )
            : null,
      ),
      body: SafeArea(
        child: _tabCount > 1 ? TabBarView(controller: _tabController, children: views) : views.first,
      ),
    );
  }

  Widget _buildSummaryTab() {
    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DatePickerRow(
            label: DateFormatter.short(_selectedDate),
            onPick: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadSummary();
              }
            },
          ),
          const SizedBox(height: 16),
          if (_loadingSummary)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_summaryError != null)
            Padding(padding: const EdgeInsets.only(top: 20), child: Text(_summaryError!, style: const TextStyle(color: AppColors.danger)))
          else if (_summary != null)
            _buildSummaryContent(_summary!),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(SalesSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _statCard('Transaksi', '${s.totalTransactions}', AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Item Terjual', '${s.totalItemsSold}', AppColors.info)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard('Omzet Bersih', CurrencyFormatter.format(s.totalNetSales), AppColors.accent)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Total Diskon', CurrencyFormatter.format(s.totalDiscount), AppColors.pending)),
          ],
        ),
        const SizedBox(height: 10),
        _statCard('PPN Terkumpul', CurrencyFormatter.format(s.totalTax), AppColors.muted, full: true),
        if (s.totalOutstanding > 0) ...[
          const SizedBox(height: 10),
          _statCard('Piutang Belum Lunas', CurrencyFormatter.format(s.totalOutstanding), AppColors.danger, full: true),
        ],
        const SizedBox(height: 20),
        const Text('Rincian per Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 10),
        if (s.byPaymentMethod.isEmpty)
          const Text('Belum ada transaksi', style: TextStyle(color: AppColors.muted))
        else
          Card(
            child: Column(
              children: s.byPaymentMethod.entries
                  .map((e) => ListTile(
                        dense: true,
                        title: Text(_paymentMethodLabels[e.key] ?? e.key),
                        trailing: Text(CurrencyFormatter.format(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
          ),
        if (s.topProducts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Produk Terlaris', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: s.topProducts.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final p = entry.value;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.accentSoft,
                    child: Text('$rank', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.accent)),
                  ),
                  title: Text(p.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(CurrencyFormatter.format(p.revenue), style: const TextStyle(fontSize: 11.5)),
                  trailing: Text('${p.qtySold} terjual', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfitLossTab() {
    return RefreshIndicator(
      onRefresh: _loadProfitLoss,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _DatePickerRow(
                  label: DateFormatter.short(_plFrom),
                  onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: _plFrom, firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (picked != null) setState(() => _plFrom = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('s/d', style: TextStyle(color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: _DatePickerRow(
                  label: DateFormatter.short(_plTo),
                  onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: _plTo, firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (picked != null) setState(() => _plTo = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _loadProfitLoss, child: const Text('Terapkan')),
          const SizedBox(height: 16),
          if (_loadingPl)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_plError != null)
            Text(_plError!, style: const TextStyle(color: AppColors.danger))
          else if (_profitLoss != null)
            _buildProfitLossContent(_profitLoss!),
        ],
      ),
    );
  }

  Widget _buildProfitLossContent(ProfitLossReport r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _plSection('Pendapatan', r.revenueAccounts, r.totalRevenue),
        const SizedBox(height: 8),
        _plRow('Harga Pokok Penjualan (HPP)', -r.costOfGoodsSold),
        const Divider(height: 24),
        _plRow('Laba Kotor', r.grossProfit, bold: true),
        const SizedBox(height: 16),
        _plSection('Beban Operasional', r.expenseAccounts, r.totalOperatingExpenses),
        const Divider(height: 24),
        _plRow('LABA BERSIH', r.netProfit, bold: true, big: true, color: r.netProfit >= 0 ? AppColors.accent : AppColors.danger),
        if (r.totalPurchasesInPeriod > 0 || r.accountsPayableBalance > 0) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Info Tambahan: Pengadaan Barang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 4),
                const Text(
                  'Pembelian tidak mengurangi laba di sini — baru jadi HPP saat barang terjual. Angka di bawah cuma info posisi pembelian & hutang usaha berjalan.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
                const SizedBox(height: 10),
                _plRow('Pembelian Periode Ini', r.totalPurchasesInPeriod),
                if (r.accountsPayableBalance > 0) _plRow('Saldo Hutang Usaha', r.accountsPayableBalance, color: AppColors.danger),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPurchasesTab() {
    return RefreshIndicator(
      onRefresh: _loadPurchasesSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _DatePickerRow(
                  label: DateFormatter.short(_purchaseFrom),
                  onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: _purchaseFrom, firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (picked != null) setState(() => _purchaseFrom = picked);
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('s/d', style: TextStyle(color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: _DatePickerRow(
                  label: DateFormatter.short(_purchaseTo),
                  onPick: () async {
                    final picked = await showDatePicker(context: context, initialDate: _purchaseTo, firstDate: DateTime(2024), lastDate: DateTime.now());
                    if (picked != null) setState(() => _purchaseTo = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _loadPurchasesSummary, child: const Text('Terapkan')),
          const SizedBox(height: 16),
          if (_loadingPurchases)
            const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
          else if (_purchasesError != null)
            Text(_purchasesError!, style: const TextStyle(color: AppColors.danger))
          else if (_purchasesSummary != null)
            _buildPurchasesContent(_purchasesSummary!),
        ],
      ),
    );
  }

  Widget _buildPurchasesContent(PurchasesSummary s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _statCard('Transaksi Pembelian', '${s.totalTransactions}', AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Total Pembelian', CurrencyFormatter.format(s.totalPurchases), AppColors.accent)),
          ],
        ),
        if (s.totalOutstandingDebt > 0) ...[
          const SizedBox(height: 10),
          _statCard('Hutang Usaha Belum Lunas', CurrencyFormatter.format(s.totalOutstandingDebt), AppColors.danger, full: true),
        ],
        const SizedBox(height: 20),
        const Text('Rincian per Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 10),
        if (s.byPaymentMethod.isEmpty)
          const Text('Belum ada pembelian', style: TextStyle(color: AppColors.muted))
        else
          Card(
            child: Column(
              children: s.byPaymentMethod.entries
                  .map((e) => ListTile(
                        dense: true,
                        title: Text(_purchasePaymentMethodLabels[e.key] ?? e.key),
                        trailing: Text(CurrencyFormatter.format(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ))
                  .toList(),
            ),
          ),
        if (s.outstandingDebts.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Daftar Hutang Usaha Belum Lunas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: s.outstandingDebts
                  .map((d) => ListTile(
                        dense: true,
                        title: Text(d.poNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(d.supplierName ?? 'Tanpa supplier', style: const TextStyle(fontSize: 11.5)),
                        trailing: Text(
                          CurrencyFormatter.format(d.outstanding),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 13),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _plSection(String title, List<ProfitLossAccount> accounts, num total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 6),
        if (accounts.isEmpty)
          const Padding(padding: EdgeInsets.only(left: 4), child: Text('-', style: TextStyle(color: AppColors.muted)))
        else
          ...accounts.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: _plRow(a.name, a.amount),
              )),
      ],
    );
  }

  Widget _plRow(String label, num amount, {bool bold = false, bool big = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontSize: big ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: TextStyle(fontSize: big ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, {bool full = false}) {
    return Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final VoidCallback onPick;
  const _DatePickerRow({required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.muted),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
