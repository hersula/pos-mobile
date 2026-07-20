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

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSummary();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final canViewAccounting = user?.canViewAccounting ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        bottom: canViewAccounting
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.ink,
                indicatorColor: AppColors.accent,
                onTap: (i) {
                  if (i == 1 && _profitLoss == null) _loadProfitLoss();
                },
                tabs: const [Tab(text: 'Tutup Kasir'), Tab(text: 'Laba Rugi')],
              )
            : null,
      ),
      body: SafeArea(
        child: canViewAccounting
            ? TabBarView(
                controller: _tabController,
                children: [_buildSummaryTab(), _buildProfitLossTab()],
              )
            : _buildSummaryTab(),
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
            Expanded(child: _statCard('Omzet Bersih', CurrencyFormatter.format(s.totalNetSales), AppColors.accent)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _statCard('Total Diskon', CurrencyFormatter.format(s.totalDiscount), AppColors.pending)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('PPN Terkumpul', CurrencyFormatter.format(s.totalTax), AppColors.muted)),
          ],
        ),
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
        Text(label, style: TextStyle(fontSize: big ? 15 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
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
