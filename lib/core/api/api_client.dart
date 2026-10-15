import 'package:dio/dio.dart';
import '../constants/app_config.dart';
import '../storage/local_storage.dart';
import 'api_exception.dart';

/// Client HTTP terpusat. Semua repository memakai instance ini supaya:
///  - Header `Authorization: Bearer <token>` otomatis terpasang
///  - Token otomatis di-refresh sekali kalau server balas 401 (expired),
///    lalu request asli diulang otomatis
///  - Kalau refresh juga gagal -> sesi dianggap habis, [onSessionExpired] dipanggil
///    supaya UI bisa redirect ke halaman login
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorage.instance.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRetry = error.requestOptions.extra['retried'] == true;

          if (isUnauthorized && !isRetry) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              final token = await LocalStorage.instance.getAccessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                // jatuh ke bawah -> anggap sesi habis
              }
            }
            onSessionExpired?.call();
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  /// Dipanggil kalau sesi benar-benar habis (refresh token juga invalid).
  /// Di-set oleh AuthProvider saat inisialisasi app.
  void Function()? onSessionExpired;

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await LocalStorage.instance.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final newAccessToken = response.data['accessToken'] as String?;
      if (newAccessToken == null) return false;

      await LocalStorage.instance.updateAccessToken(newAccessToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    return _handle(() => _dio.get(path, queryParameters: query));
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    return _handle(() => _dio.post(path, data: data));
  }

  /// Kirim file (multipart/form-data). Dipakai untuk upload gambar produk.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData formData,
    void Function(int sent, int total)? onProgress,
  }) async {
    return _handle(
      () => _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onProgress,
      ),
    );
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    return _handle(() => _dio.put(path, data: data));
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    return _handle(() => _dio.delete(path, data: data));
  }

  Future<Map<String, dynamic>> _handle(Future<Response> Function() request) async {
    try {
      final response = await request();
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'data': response.data};
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Tidak bisa terhubung ke server. Periksa koneksi internet kamu.';
      throw ApiException(
        message,
        statusCode: e.response?.statusCode,
        data: data is Map<String, dynamic> ? data : null,
      );
    }
  }
}
