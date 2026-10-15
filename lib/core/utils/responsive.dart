/// Breakpoint lebar layar (dp) mengikuti kelas ukuran Material Design:
/// compact (HP), medium (tablet portrait), expanded (tablet landscape/besar).
class Responsive {
  static const double medium = 600;
  static const double expanded = 900;

  /// Jumlah kolom grid berdasarkan lebar area yang tersedia (bukan lebar layar penuh,
  /// supaya tetap benar saat widget ada di dalam layout terbatas seperti split-screen).
  static int gridColumns(
    double width, {
    int compact = 2,
    int mediumCols = 3,
    int expandedCols = 4,
  }) {
    if (width >= expanded) return expandedCols;
    if (width >= medium) return mediumCols;
    return compact;
  }
}
