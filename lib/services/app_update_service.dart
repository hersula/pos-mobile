import 'package:package_info_plus/package_info_plus.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../data/models/app_version_info.dart';

/// Service untuk memeriksa versi app terbaru dari server.
/// Memanggil GET /api/app/version dengan parameter:
/// - platform: android (hardcoded untuk mobile)
/// - version: versi app lokal (mis. 1.0.0)
/// - build: build number lokal (mis. 1)
class AppUpdateService {
  static const String _platformAndroid = 'android';
  final ApiClient _client = ApiClient.instance;

  /// Ambil informasi versi terbaru dari server.
  /// Kegagalan jaringan/timeout/error API → throw exception dengan pesan yang ramah.
  Future<AppVersionInfo> checkLatestVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version; // mis. 1.0.0
      final buildNumber =
          packageInfo.buildNumber; // mis. 1 (sebagai string, konversi ke int)

      final res = await _client.get(
        ApiEndpoints.appVersion,
        query: {
          'platform': _platformAndroid,
          'version': version,
          'build': buildNumber,
        },
      );

      // Respons: { data: { latestVersion, ... } } atau langsung { latestVersion, ... }
      // Ikuti pola repo lain: data bisa di dalam 'data' key atau langsung
      final data = res['data'] is Map<String, dynamic> ? res['data'] : res;
      return AppVersionInfo.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}
