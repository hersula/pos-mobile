import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/constants/app_config.dart';
import 'package:pos_mobile/core/api/api_endpoints.dart';

void main() {
  test('normalizeBaseUrl', () {
    expect(AppConfig.normalizeBaseUrl('https://pos.quantix.id/api/'),
        'https://pos.quantix.id');
    expect(AppConfig.normalizeBaseUrl('http://10.0.2.2:3000/'),
        'http://10.0.2.2:3000');
  });

  test('URL login produksi tanpa garis miring ganda', () {
    expect('${AppConfig.apiBaseUrl}${ApiEndpoints.login}',
        'https://pos.quantix.id/api/auth/login');
  });

  test('login live: 401 JSON diterima (butuh internet)', () async {
    final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {'Accept': 'application/json'},
        validateStatus: (_) => true));
    final r = await dio.post(ApiEndpoints.login,
        data: {'email': 'tidak-ada@example.com', 'password': 'salah'});
    expect(r.statusCode, 401);
    expect((r.data as Map)['message'], isNotEmpty);
  }, tags: 'network');
}
