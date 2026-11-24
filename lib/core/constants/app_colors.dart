import 'package:flutter/material.dart';

/// Palet Q-Pos tema "Warm Roastery" (v1.0.2), varian TERANG, sebagai
/// konstanta. Ini sumber nilai warna terang: [PosColors.light]
/// (pos_colors.dart) merujuk ke konstanta di sini, sedangkan varian gelap
/// ada di [PosColors.dark].
///
/// Latar krem hangat + kartu putih, Burnt Orange sebagai brand & aksi utama,
/// Coffee Brown khusus tombol penyelesaian pembayaran.
///
/// Nama token tidak berubah dari palet sebelumnya, jadi seluruh layar ikut
/// berganti tanpa disentuh. `AppColors.x` selalu terang; layar yang perlu
/// mendukung mode gelap memakai `context.pos.x` (ikut tema aktif).
///
/// Aturan pakai (kontras sudah dicek WCAG AA >= 4.5:1):
/// - [accent] = aksi utama & teks aksen. Teks di atasnya: [onAccent].
/// - [brand] (#EA580C) hanya non-teks: kontras ke putih cuma 3.56:1.
/// - [ember] khusus tombol penyelesaian pembayaran (cart_panel.dart &
///   checkout_screen.dart). Teks di atasnya: [onEmber].
class AppColors {
  AppColors._();

  static const ink = Color(0xFF292524);
  static const inkSoft = Color(0xFF44403C);
  static const paper = Color(0xFFFAF7F2); // krem hangat
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFE8E1D8);
  static const text = Color(0xFF292524);
  static const muted = Color(0xFF6B635D);

  static const accent = Color(0xFFC2410C); // Burnt Orange tua: 5.18:1 dgn putih
  static const onAccent = Color(0xFFFFFFFF);
  static const accentSoft = Color(0xFFFFEDD5);
  static const brand = Color(0xFFEA580C); // Burnt Orange, non-teks saja

  static const ember = Color(0xFF78350F); // Coffee Brown: 9.07:1 dgn putih
  static const onEmber = Color(0xFFFFFFFF);
  static const emberSoft = Color(0xFFF7EDE3);

  // Kuning tua (bukan amber) supaya status "pending" tidak tertukar dengan
  // warna aksi utama yang oranye.
  static const pending = Color(0xFFA16207);
  static const pendingSoft = Color(0xFFFEF9C3);

  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFE7F6EC);

  static const danger = Color(0xFFB91C1C);
  static const dangerSoft = Color(0xFFFDECEA);

  static const info = Color(0xFF1D4ED8);
  static const infoSoft = Color(0xFFE8EEFC);

  static const productImageBg = Color(0xFFF3EEE7);
}
