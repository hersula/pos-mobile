import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/stock_opname_repository.dart';

/// Dialog batalkan sesi (alasan opsional; backend mewajibkan 3-500 karakter,
/// jadi bila kosong dipakai alasan bawaan). Mengembalikan true bila berhasil.
Future<bool> confirmCancelOpname(BuildContext context, String id, StockOpnameRepository repo) async {
  final ctrl = TextEditingController();
  String? error;
  bool busy = false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Batalkan sesi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stok tidak berubah. Sesi yang dibatalkan tidak dapat dilanjutkan.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              enabled: !busy,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Alasan (opsional)'),
            ),
            if (error != null) Text(error!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ],
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Kembali')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: busy
                ? null
                : () async {
                    final reason = ctrl.text.trim();
                    if (reason.isNotEmpty && reason.length < 3) {
                      setSt(() => error = 'Alasan minimal 3 karakter.');
                      return;
                    }
                    setSt(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await repo.cancel(id, reason.isEmpty ? 'Dibatalkan oleh pengguna' : reason);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on ApiException catch (e) {
                      setSt(() {
                        busy = false;
                        error = e.message;
                      });
                    }
                  },
            child: Text(busy ? 'Memproses...' : 'Ya, Batalkan'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return ok == true;
}
