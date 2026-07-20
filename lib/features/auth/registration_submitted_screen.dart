import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class RegistrationSubmittedScreen extends StatelessWidget {
  final String planType;

  const RegistrationSubmittedScreen({super.key, required this.planType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  decoration: const BoxDecoration(color: AppColors.pendingSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.hourglass_top_rounded, color: AppColors.pending, size: 34),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Pendaftaran Terkirim',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 10),
                Text(
                  planType == 'SUBSCRIBE'
                      ? 'Tim kami akan meninjau data usahamu dan menghubungimu untuk proses langganan. Kamu akan bisa login setelah akun disetujui admin.'
                      : 'Tim kami akan meninjau data usahamu terlebih dahulu. Kamu akan bisa login setelah akun disetujui admin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: const Text('Kembali ke Halaman Masuk'),
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
