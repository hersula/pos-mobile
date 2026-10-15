import 'package:flutter/material.dart';

/// Palet Q-Pos: ink hijau-gelap + emerald sebagai warna aksi utama/brand,
/// dan ember (jingga) yang sengaja dibatasi cuma untuk tombol penyelesaian
/// pembayaran (lihat cart_panel.dart & checkout_screen.dart) supaya tetap
/// terasa istimewa, bukan warna yang dipakai di mana-mana.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF16231C);
  static const inkSoft = Color(0xFF3A4A3F);
  static const paper = Color(0xFFEEF1EA);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD7DCCF);
  static const text = Color(0xFF1A241D);
  static const muted = Color(0xFF68776B);

  static const accent = Color(0xFF0E6B4A); // emerald - brand & aksi utama
  static const accentSoft = Color(0xFFE2F1E9);

  static const ember = Color(0xFFE3572C); // aksen bayar/total - khusus CTA pembayaran
  static const emberSoft = Color(0xFFFBE3D8);

  static const pending = Color(0xFFB8862E); // amber
  static const pendingSoft = Color(0xFFFAF1E1);

  static const success = Color(0xFF0E6B4A);
  static const successSoft = Color(0xFFE2F1E9);

  static const danger = Color(0xFFA23B32);
  static const dangerSoft = Color(0xFFF7E8E6);

  static const info = Color(0xFF3454D1);
  static const infoSoft = Color(0xFFE7EAFB);
}
