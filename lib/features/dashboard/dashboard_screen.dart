import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _reportsTabIndex = 2;

  int _index = 0;
  final GlobalKey<ReportsScreenState> _reportsKey = GlobalKey<ReportsScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const PosScreen(),
      const ProductListScreen(),
      ReportsScreen(key: _reportsKey),
      const SettingsScreen(),
    ];
  }

  void _onDestinationSelected(int index) {
    setState(() => _index = index);

    // Refresh otomatis setiap kali kasir/owner pindah ke tab Laporan, supaya
    // angka penjualan/laba-rugi/pembelian selalu terbaru tanpa perlu
    // tarik-refresh manual. ReportsScreen tetap hidup di IndexedStack (state-nya
    // tidak hilang saat pindah tab), jadi butuh trigger manual lewat GlobalKey ini.
    if (index == _reportsTabIndex) {
      _reportsKey.currentState?.refreshActiveTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Inventori'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Pengaturan'),
        ],
      ),
    );
  }
}
