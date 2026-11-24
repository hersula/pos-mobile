import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Token warna POS sebagai [ThemeExtension], dengan varian terang & gelap.
///
/// Tema "Warm Roastery" (v1.0.2): latar krem hangat, Burnt Orange sebagai
/// brand & aksi utama, Coffee Brown khusus tombol penyelesaian pembayaran.
///
/// Dua cara pakai:
/// - `AppColors.x` (konstanta, selalu varian terang, sumber nilai [light]) —
///   cara lama, dipakai 449 tempat. Aman untuk tema terang.
/// - `context.pos.x` — ikut tema aktif (terang/gelap). Layar yang ingin
///   mendukung mode gelap dimigrasi ke sini satu per satu
///   (lihat docs/manual/tema.md).
///
/// Kontras teks sudah dicek WCAG AA (>= 4.5:1) untuk tiap pasangan
/// teks/latar di bawah, kecuali [brand] yang sengaja hanya untuk non-teks.
@immutable
class PosColors extends ThemeExtension<PosColors> {
  final Color ink;
  final Color inkSoft;
  final Color paper;
  final Color surface;
  final Color line;
  final Color text;
  final Color muted;

  /// Aksi utama & teks aksen (harga, tab terpilih). Teks di atasnya: [onAccent].
  final Color accent;
  final Color onAccent;
  final Color accentSoft;

  /// Burnt Orange cerah #EA580C. Kontras ke putih hanya 3.56:1, jadi HANYA
  /// untuk elemen non-teks: FAB, indikator, garis fokus, badge ikon.
  final Color brand;

  /// CTA pembayaran (Bayar / Selesaikan Pembayaran). Teks di atasnya: [onEmber].
  final Color ember;
  final Color onEmber;
  final Color emberSoft;

  final Color pending;
  final Color pendingSoft;
  final Color success;
  final Color successSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// Latar kotak foto produk di grid katalog (terlihat saat foto belum ada).
  final Color productImageBg;

  const PosColors({
    required this.ink,
    required this.inkSoft,
    required this.paper,
    required this.surface,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.brand,
    required this.ember,
    required this.onEmber,
    required this.emberSoft,
    required this.pending,
    required this.pendingSoft,
    required this.success,
    required this.successSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.productImageBg,
  });

  /// Varian terang: nilainya dari [AppColors] (satu sumber, tetap `const`).
  static const light = PosColors(
    ink: AppColors.ink,
    inkSoft: AppColors.inkSoft,
    paper: AppColors.paper,
    surface: AppColors.surface,
    line: AppColors.line,
    text: AppColors.text,
    muted: AppColors.muted,
    accent: AppColors.accent,
    onAccent: AppColors.onAccent,
    accentSoft: AppColors.accentSoft,
    brand: AppColors.brand,
    ember: AppColors.ember,
    onEmber: AppColors.onEmber,
    emberSoft: AppColors.emberSoft,
    pending: AppColors.pending,
    pendingSoft: AppColors.pendingSoft,
    success: AppColors.success,
    successSoft: AppColors.successSoft,
    danger: AppColors.danger,
    dangerSoft: AppColors.dangerSoft,
    info: AppColors.info,
    infoSoft: AppColors.infoSoft,
    productImageBg: AppColors.productImageBg,
  );

  static const dark = PosColors(
    ink: Color(0xFFF5F5F4),
    inkSoft: Color(0xFFD6D3D1),
    paper: Color(0xFF1C1917),
    surface: Color(0xFF292524),
    line: Color(0xFF44403C),
    text: Color(0xFFF5F5F4),
    muted: Color(0xFFA8A29E),
    accent: Color(0xFFFB923C),
    onAccent: Color(0xFF1C1917), // teks gelap di oranye terang: 7.73:1
    accentSoft: Color(0xFF431407),
    brand: Color(0xFFFB923C),
    ember: Color(0xFFE7B98A), // latte
    onEmber: Color(0xFF1C1917),
    emberSoft: Color(0xFF3B2A1E),
    pending: Color(0xFFFACC15),
    pendingSoft: Color(0xFF422006),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF052E16),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF450A0A),
    info: Color(0xFF60A5FA),
    infoSoft: Color(0xFF172554),
    productImageBg: Color(0xFF312C29),
  );

  @override
  PosColors copyWith({
    Color? ink,
    Color? inkSoft,
    Color? paper,
    Color? surface,
    Color? line,
    Color? text,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? brand,
    Color? ember,
    Color? onEmber,
    Color? emberSoft,
    Color? pending,
    Color? pendingSoft,
    Color? success,
    Color? successSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? productImageBg,
  }) {
    return PosColors(
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      paper: paper ?? this.paper,
      surface: surface ?? this.surface,
      line: line ?? this.line,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentSoft: accentSoft ?? this.accentSoft,
      brand: brand ?? this.brand,
      ember: ember ?? this.ember,
      onEmber: onEmber ?? this.onEmber,
      emberSoft: emberSoft ?? this.emberSoft,
      pending: pending ?? this.pending,
      pendingSoft: pendingSoft ?? this.pendingSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      productImageBg: productImageBg ?? this.productImageBg,
    );
  }

  @override
  PosColors lerp(ThemeExtension<PosColors>? other, double t) {
    if (other is! PosColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PosColors(
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      paper: l(paper, other.paper),
      surface: l(surface, other.surface),
      line: l(line, other.line),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      brand: l(brand, other.brand),
      ember: l(ember, other.ember),
      onEmber: l(onEmber, other.onEmber),
      emberSoft: l(emberSoft, other.emberSoft),
      pending: l(pending, other.pending),
      pendingSoft: l(pendingSoft, other.pendingSoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      productImageBg: l(productImageBg, other.productImageBg),
    );
  }
}

extension PosColorsContext on BuildContext {
  /// Token warna POS untuk tema aktif. Jatuh ke [PosColors.light] kalau
  /// widget berada di luar MaterialApp (mis. di test widget tanpa tema).
  PosColors get pos => Theme.of(this).extension<PosColors>() ?? PosColors.light;
}
