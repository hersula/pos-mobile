/// Konfigurasi umum aplikasi. Ganti [baseUrl] sesuai alamat backend:
/// - Emulator Android -> http://10.0.2.2:3000
/// - Device fisik/production -> https://api.tokokamu.com
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String apiPrefix = '/api';

  static String get apiBaseUrl => '$baseUrl$apiPrefix';

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
