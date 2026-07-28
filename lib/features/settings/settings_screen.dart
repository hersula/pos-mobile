import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/auth_provider.dart';
import 'printer_settings_screen.dart';
import 'subscription_card.dart';

const _roleLabels = {
  'OWNER': 'Pemilik',
  'MANAGER': 'Manajer',
  'KASIR': 'Kasir',
  'GUDANG': 'Gudang',
  'AKUNTAN': 'Akuntan',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Kamu perlu login ulang untuk memakai aplikasi ini lagi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, color: AppColors.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(user?.email ?? '-', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              _roleLabels[user?.role] ?? user?.role ?? '-',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront_rounded, color: AppColors.muted),
                      title: Text(user?.tenant.businessName ?? '-'),
                      subtitle: Text('Paket ${user?.tenant.planType == 'FREE' ? 'Gratis' : 'Berlangganan'}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SubscriptionCard(isOwner: user?.role == 'OWNER'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.print_rounded, color: AppColors.muted),
                    title: const Text('Printer Bluetooth'),
                    subtitle: const Text('Sambungkan printer struk thermal'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              label: const Text('Keluar', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}
