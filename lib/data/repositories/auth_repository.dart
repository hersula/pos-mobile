import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/user_profile.dart';

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final UserProfile user;

  LoginResult({required this.accessToken, required this.refreshToken, required this.user});
}

class AuthRepository {
  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> registerTenant({
    required String businessName,
    required String ownerName,
    required String email,
    String? phone,
    String? address,
    required String password,
    required String planType, // FREE | SUBSCRIBE
  }) async {
    return _client.post(ApiEndpoints.registerTenant, data: {
      'businessName': businessName,
      'ownerName': ownerName,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      'password': password,
      'planType': planType,
    });
  }

  /// Melempar [ApiException] dengan pesan status PENDING/REJECTED/SUSPENDED
  /// kalau tenant belum boleh login (lihat backend `/api/auth/login`).
  Future<LoginResult> login({required String email, required String password}) async {
    final res = await _client.post(ApiEndpoints.login, data: {'email': email, 'password': password});

    return LoginResult(
      accessToken: res['accessToken'] as String,
      refreshToken: res['refreshToken'] as String,
      user: UserProfile.fromJson(res['user'] as Map<String, dynamic>),
    );
  }
}
