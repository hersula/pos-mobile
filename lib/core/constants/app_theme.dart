import 'package:flutter/material.dart';
import 'pos_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(PosColors.light, Brightness.light);

  /// Siap dipakai, tapi belum diaktifkan di MaterialApp (themeMode: light):
  /// layar yang masih memakai konstanta `AppColors.x` tidak ikut gelap, jadi
  /// mode gelap baru dinyalakan setelah layar dimigrasi ke `context.pos.x`
  /// (lihat docs/manual/tema.md).
  static ThemeData get dark => _build(PosColors.dark, Brightness.dark);

  // Tema "Warm Roastery" (v1.0.2): Burnt Orange = primary (aksi utama),
  // Coffee Brown = secondary (CTA bayar), latar krem + kartu putih.
  static ThemeData _build(PosColors c, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        primaryContainer: c.accentSoft,
        onPrimaryContainer: c.accent,
        secondary: c.ember,
        onSecondary: c.onEmber,
        secondaryContainer: c.emberSoft,
        error: c.danger,
        surface: c.surface,
        onSurface: c.text,
        onSurfaceVariant: c.muted,
        outline: c.line,
        outlineVariant: c.line,
      ),
      scaffoldBackgroundColor: c.paper,
      // Mulish untuk isi/body (brand Q-Pos) — menggantikan Roboto bawaan.
      // Judul (AppBar dkk) pakai Archivo, lihat appBarTheme di bawah.
      // Keduanya font open-source (SIL OFL), lihat assets/fonts/OFL-*.txt.
      fontFamily: 'Mulish',
      extensions: [c],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        // Garis tipis di bawah AppBar putih (gaya "clean"), tanpa bayangan.
        shape: Border(bottom: BorderSide(color: c.line)),
        titleTextStyle: TextStyle(
          fontFamily: 'Archivo',
          color: c.text,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      // textStyle tombol MENGGANTIKAN gaya teks bawaan (bukan digabung), jadi
      // fontFamily wajib ditulis lagi; tanpa itu tombol jatuh ke Roboto.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontFamily: 'Mulish', fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontFamily: 'Mulish', fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontFamily: 'Mulish', fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: const TextStyle(
              fontFamily: 'Mulish', fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.paper,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.line),
        ),
        // Garis fokus = non-teks, jadi boleh pakai brand (#EA580C) yang cerah.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brand, width: 1.8),
        ),
        labelStyle: TextStyle(color: c.muted, fontSize: 13.5),
        floatingLabelStyle: TextStyle(color: c.accent, fontSize: 13.5),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? c.accent : c.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? c.accent : c.muted,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.accent,
        unselectedLabelColor: c.muted,
        indicatorColor: c.brand,
        dividerColor: c.line,
      ),
      // FAB = ikon (non-teks), jadi pakai brand cerah; ikon putih 3.56:1
      // memenuhi batas 3:1 untuk elemen grafis.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.brand,
        foregroundColor: c.onAccent,
        elevation: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.line),
        labelStyle: TextStyle(color: c.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand),
      snackBarTheme: SnackBarThemeData(
        // Selalu latar gelap (di mode gelap pakai surface) agar kontras.
        backgroundColor: brightness == Brightness.light ? c.ink : c.inkSoft,
        contentTextStyle: TextStyle(
          color: brightness == Brightness.light ? c.surface : c.paper,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
