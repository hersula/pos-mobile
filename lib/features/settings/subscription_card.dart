import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/subscription_status.dart';
import '../../data/repositories/subscription_repository.dart';

const _statusLabels = {
  'TRIAL': 'Masa Coba (Trial)',
  'ACTIVE': 'Aktif',
  'PENDING_PAYMENT': 'Menunggu Konfirmasi',
  'EXPIRED': 'Sudah Berakhir',
  'CANCELLED': 'Dibatalkan',
};

const _statusColors = {
  'TRIAL': AppColors.pending,
  'ACTIVE': AppColors.accent,
  'PENDING_PAYMENT': AppColors.pending,
  'EXPIRED': AppColors.danger,
  'CANCELLED': AppColors.muted,
};

class SubscriptionCard extends StatefulWidget {
  final bool isOwner;
  const SubscriptionCard({super.key, required this.isOwner});

  @override
  State<SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<SubscriptionCard> {
  final _repo = SubscriptionRepository();
  TenantSubscriptionStatus? _status;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _repo.getStatus();
      if (mounted) setState(() => _status = status);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmUpgrade() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upgrade ke Berlangganan?'),
        content: const Text(
          'Kamu akan langsung dapat masa coba gratis 30 hari dengan transaksi tanpa batas. Setelah masa coba habis, tinggal ajukan pembayaran untuk lanjut.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upgrade Sekarang')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await _repo.upgradeToSubscribe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil upgrade! Trial 30 hari sudah mulai berjalan.'), backgroundColor: AppColors.accent),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showRequestPaymentDialog() async {
    final noteCtrl = TextEditingController();
    bool submitting = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajukan Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sudah transfer pembayaran langganan? Tulis catatan singkat (mis. bank & nominal), lalu tim kami akan konfirmasi secepatnya.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              if (dialogError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
                ),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Contoh: Sudah transfer Rp150.000 via BCA a.n. Budi'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: submitting ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        await _repo.requestPayment(note: noteCtrl.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pengajuan terkirim, menunggu konfirmasi admin.'), backgroundColor: AppColors.accent),
                          );
                        }
                        await _load();
                      } on ApiException catch (e) {
                        setDialogState(() {
                          dialogError = e.message;
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null || _status == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(_error ?? 'Gagal memuat status langganan', style: const TextStyle(color: AppColors.muted, fontSize: 12.5))),
              TextButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    final status = _status!;
    return status.isFree ? _buildFreeCard(status) : _buildSubscribeCard(status);
  }

  Widget _buildFreeCard(TenantSubscriptionStatus status) {
    final used = status.dailyTransactionUsed ?? 0;
    final limit = status.dailyTransactionLimit ?? 10;
    final remaining = status.dailyTransactionRemaining ?? (limit - used);
    final progress = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final isNearLimit = remaining <= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(6)),
                  child: const Text('PAKET GRATIS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('$used dari $limit transaksi hari ini', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.paper,
                color: isNearLimit ? AppColors.danger : AppColors.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              remaining > 0 ? '$remaining transaksi tersisa hari ini' : 'Batas transaksi harian sudah tercapai',
              style: TextStyle(fontSize: 12, color: isNearLimit ? AppColors.danger : AppColors.muted, fontWeight: isNearLimit ? FontWeight.w700 : FontWeight.w400),
            ),
            const SizedBox(height: 14),
            if (widget.isOwner)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _confirmUpgrade,
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: Text(_submitting ? 'Memproses...' : 'Upgrade ke Berlangganan'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink),
                ),
              )
            else
              const Text(
                'Hubungi pemilik toko untuk upgrade ke paket Berlangganan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            const SizedBox(height: 6),
            const Text(
              'Berlangganan = transaksi tanpa batas + trial gratis 30 hari.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeCard(TenantSubscriptionStatus status) {
    final sub = status.subscription;
    if (sub == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Data langganan tidak ditemukan. Hubungi admin.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ),
      );
    }

    final color = _statusColors[sub.status] ?? AppColors.muted;
    final canRequestPayment = sub.status != 'PENDING_PAYMENT';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(6)),
                  child: const Text('BERLANGGANAN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    _statusLabels[sub.status] ?? sub.status,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sub.status == 'TRIAL' || sub.status == 'ACTIVE') ...[
              Text(
                sub.daysRemaining > 0 ? '${sub.daysRemaining} hari lagi' : 'Berakhir hari ini',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.ink),
              ),
              Text(
                sub.status == 'TRIAL' ? 'sampai masa coba gratis berakhir' : 'sampai langganan perlu diperpanjang',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ] else if (sub.status == 'PENDING_PAYMENT') ...[
              const Text(
                'Pengajuan pembayaran kamu sedang ditinjau tim kami. Mohon tunggu konfirmasi.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ] else ...[
              const Text(
                'Masa langganan sudah berakhir. Ajukan pembayaran untuk melanjutkan — data toko kamu tetap aman tersimpan.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 14),
            if (!widget.isOwner)
              const Text(
                'Hubungi pemilik toko untuk mengajukan pembayaran.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              )
            else if (canRequestPayment)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showRequestPaymentDialog,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Ajukan Pembayaran'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: AppColors.pendingSoft, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Text('Menunggu konfirmasi admin', style: TextStyle(color: AppColors.pending, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
          ],
        ),
      ),
    );
  }
}
