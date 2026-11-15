/// Konfigurasi umum aplikasi. Default = produksi (https://pos.quantix.id).
/// Override untuk dev lewat `--dart-define=API_BASE_URL=...`:
/// - Emulator Android -> http://10.0.2.2:3000
/// Nilai boleh dengan/tanpa akhiran `/api` dan garis miring; dinormalkan.
class AppConfig {
  static const String _rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://pos.quantix.id',
  );

  static const String apiPrefix = '/api';

  /// Host saja (tanpa `/api`, tanpa garis miring akhir).
  static final String baseUrl = normalizeBaseUrl(_rawBaseUrl);

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

  static String normalizeBaseUrl(String raw) {
    var u = raw.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith(apiPrefix)) u = u.substring(0, u.length - apiPrefix.length);
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Ubah path gambar relatif dari server (mis. `/uploads/product-1.jpg`)
  /// menjadi URL absolut yang bisa dipakai Image.network.
  /// Kalau sudah absolut (http/https), dikembalikan apa adanya.
  static String? resolveImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final p = path.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return p.startsWith('/') ? '$baseUrl$p' : '$baseUrl/$p';
  }
}
