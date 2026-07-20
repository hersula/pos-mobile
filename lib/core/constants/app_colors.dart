import 'package:flutter/material.dart';

/// Palet warna konsisten dengan Admin Panel web (tema "Gerbang"):
/// ink navy sebagai warna utama, teal sebagai aksen, dan warna status
/// bergaya "cap stempel" (pending/approved/rejected) dipakai berulang
/// untuk status transaksi & piutang di modul penjualan.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF10192B);
  static const inkSoft = Color(0xFF1C2942);
  static const paper = Color(0xFFF2F3EF);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDFE2DA);
  static const text = Color(0xFF1B2430);
  static const muted = Color(0xFF6B7280);

  static const accent = Color(0xFF1F6F5C); // teal - aksi utama
  static const accentSoft = Color(0xFFE4EFEC);

  static const pending = Color(0xFFB8862E); // amber
  static const pendingSoft = Color(0xFFFAF1E1);

  static const success = Color(0xFF1F6F5C);
  static const successSoft = Color(0xFFE4EFEC);

  static const danger = Color(0xFFA23B32);
  static const dangerSoft = Color(0xFFF7E8E6);

  static const info = Color(0xFF3454D1);
  static const infoSoft = Color(0xFFE7EAFB);
}
