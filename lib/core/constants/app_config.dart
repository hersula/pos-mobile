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
}
