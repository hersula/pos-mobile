import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PendingStatusArgs {
  final String status; // PENDING | REJECTED | SUSPENDED | SUBSCRIPTION_EXPIRED
  final String message;
  PendingStatusArgs({required this.status, required this.message});
}

class PendingStatusScreen extends StatelessWidget {
  final PendingStatusArgs args;

  const PendingStatusScreen({super.key, required this.args});

  ({IconData icon, Color color, Color bg, String title}) get _visual {
    switch (args.status) {
      case 'REJECTED':
        return (
          icon: Icons.block_rounded,
          color: AppColors.danger,
          bg: AppColors.dangerSoft,
          title: 'Pendaftaran Ditolak',
        );
      case 'SUSPENDED':
        return (
          icon: Icons.pause_circle_outline_rounded,
          color: AppColors.muted,
          bg: AppColors.paper,
          title: 'Akun Ditangguhkan',
        );
      case 'SUBSCRIPTION_EXPIRED':
        return (
          icon: Icons.workspace_premium_outlined,
          color: AppColors.pending,
          bg: AppColors.pendingSoft,
          title: 'Langganan Berakhir',
        );
      case 'PENDING':
      default:
        return (
          icon: Icons.hourglass_top_rounded,
          color: AppColors.pending,
          bg: AppColors.pendingSoft,
          title: 'Menunggu Persetujuan',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    return Scaffold(
      appBar: AppBar(title: const Text('Status Akun')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: v.bg, shape: BoxShape.circle),
                  child: Icon(v.icon, color: v.color, size: 34),
                ),
                const SizedBox(height: 24),
                Text(v.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 10),
                Text(
                  args.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kembali'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
