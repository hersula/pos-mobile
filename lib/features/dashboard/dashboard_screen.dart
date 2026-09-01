import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_provider.dart';
import '../inventory/product_list_screen.dart';
import '../pos/pos_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

class _MenuTab {
  final String key;
  final Widget screen;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _MenuTab({required this.key, required this.screen, required this.icon, required this.selectedIcon, required this.label});
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  final GlobalKey<ReportsScreenState> _reportsKey = GlobalKey<ReportsScreenState>();

  late final List<_MenuTab> _allTabs = [
    const _MenuTab(key: 'kasir', screen: PosScreen(), icon: Icons.point_of_sale_outlined, selectedIcon: Icons.point_of_sale_rounded, label: 'Kasir'),
    const _MenuTab(key: 'inventori', screen: ProductListScreen(), icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Inventori'),
    _MenuTab(key: 'laporan', screen: ReportsScreen(key: _reportsKey), icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Laporan'),
    const _MenuTab(key: 'pengaturan', screen: SettingsScreen(), icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Pengaturan'),
  ];

  List<_MenuTab> _visibleTabs(UserProfile? user) {
    if (user == null) return _allTabs;
    return _allTabs.where((t) => user.menuAccess.contains(t.key)).toList();
  }

  void _onDestinationSelected(List<_MenuTab> tabs, int index) {
    setState(() => _index = index);

    // Refresh otomatis setiap kali kasir/owner pindah ke tab Laporan, supaya
    // angka penjualan/laba-rugi/pembelian selalu terbaru tanpa perlu
    // tarik-refresh manual. ReportsScreen tetap hidup di IndexedStack (state-nya
    // tidak hilang saat pindah tab), jadi butuh trigger manual lewat GlobalKey ini.
    if (tabs[index].key == 'laporan') {
      _reportsKey.currentState?.refreshActiveTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final tabs = _visibleTabs(user);
    final index = _index >= tabs.length ? 0 : _index;

    return Scaffold(
      body: IndexedStack(index: index, children: tabs.map((t) => t.screen).toList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _onDestinationSelected(tabs, i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSoft,
        destinations: tabs
            .map((t) => NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label))
            .toList(),
      ),
    );
  }
}
