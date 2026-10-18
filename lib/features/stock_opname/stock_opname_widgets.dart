import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/stock_opname.dart';

Color opnameStatusColor(String status) {
  switch (status) {
    case 'DRAFT':
      return AppColors.pending;
    case 'COMPLETED':
      return AppColors.success;
    default:
      return AppColors.muted;
  }
}

/// Rupiah dengan tanda eksplisit (+/-).
String signedRupiah(num v) {
  if (v == 0) return CurrencyFormatter.format(0);
  return '${v > 0 ? '+' : '-'}${CurrencyFormatter.format(v.abs())}';
}

String signedQty(num v) => v > 0 ? '+${fmtQty(v)}' : fmtQty(v);

Color diffColor(num v, {bool muted = false}) {
  if (muted || v == 0) return AppColors.muted;
  return v > 0 ? AppColors.info : AppColors.danger;
}

enum BannerKind { info, pending, danger }

class OpnameBanner extends StatelessWidget {
  final BannerKind kind;
  final String text;
  final Widget? action;

  const OpnameBanner({super.key, required this.kind, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      BannerKind.info => (AppColors.infoSoft, AppColors.info, Icons.info_outline_rounded),
      BannerKind.pending => (AppColors.pendingSoft, AppColors.pending, Icons.hourglass_empty_rounded),
      BannerKind.danger => (AppColors.dangerSoft, AppColors.danger, Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: kind == BannerKind.danger,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w600))),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

/// Tag selisih real-time: Belum / Cocok / +N lebih / -N kurang.
class DiffTag extends StatelessWidget {
  final num? diff; // null = belum dihitung
  const DiffTag({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    final d = diff;
    if (d == null) {
      label = 'Belum';
      bg = AppColors.pendingSoft;
      fg = AppColors.pending;
    } else if (d == 0) {
      label = 'Cocok';
      bg = AppColors.accentSoft;
      fg = AppColors.accent;
    } else if (d > 0) {
      label = '+${fmtQty(d)} lebih';
      bg = AppColors.infoSoft;
      fg = AppColors.info;
    } else {
      label = '-${fmtQty(d.abs())} kurang';
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const SummaryBox({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}

/// Baris selisih (dipakai Review dan Detail).
class DiffRow extends StatelessWidget {
  final OpnameItem item;
  final bool mutedColors;

  const DiffRow({super.key, required this.item, this.mutedColors = false});

  @override
  Widget build(BuildContext context) {
    final d = item.diff ?? 0;
    final color = diffColor(d, muted: mutedColors);
    final fisik = item.countedQty == null ? '-' : fmtQty(item.countedQty!);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Sistem ${fmtQty(item.systemQty)} · Fisik $fisik · ${signedRupiah(item.diffValue)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: d == 0 ? 'Cocok' : (d > 0 ? 'Lebih ${fmtQty(d)}' : 'Kurang ${fmtQty(d.abs())}'),
              excludeSemantics: true,
              child: Text(signedQty(d), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

Widget opnameChip({
  required String label,
  required bool selected,
  required Color color,
  required VoidCallback onTap,
}) {
  return Semantics(
    button: true,
    selected: selected,
    label: 'Filter $label',
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : AppColors.line),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? color : AppColors.muted)),
          ),
        ),
      ),
    ),
  );
}

/// Pesan error + Coba Lagi.
class OpnameErrorView extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback onRetry;

  const OpnameErrorView({super.key, required this.title, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text(message ?? 'Periksa koneksi internet Anda, lalu coba lagi.',
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

/// Bungkus konten agar maksimal 640dp di tengah pada tablet.
class CenteredColumn extends StatelessWidget {
  final Widget child;
  const CenteredColumn({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child));
}

/// Bar aksi bawah putih dengan border atas.
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  const BottomActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
      child: SafeArea(
        top: false,
        child: CenteredColumn(child: Row(children: children)),
      ),
    );
  }
}
