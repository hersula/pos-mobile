import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/storage/local_storage.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  AuthStatus status = AuthStatus.unknown;
  UserProfile? currentUser;

  AuthProvider() {
    ApiClient.instance.onSessionExpired = _handleSessionExpired;
  }

  Future<void> restoreSession() async {
    final token = await LocalStorage.instance.getAccessToken();
    final profileJson = await LocalStorage.instance.getUserProfile();

    if (token != null && profileJson != null) {
      currentUser = UserProfile.fromJson(profileJson);
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Melempar [ApiException]. Kalau statusCode 403 dengan `data['tenantStatus']`
  /// terisi (PENDING/REJECTED/SUSPENDED), layar login akan mengarahkan ke
  /// halaman status yang sesuai alih-alih menampilkan error generik.
  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);

    await LocalStorage.instance.saveSession(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      userProfile: result.user.toJson(),
    );

    currentUser = result.user;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await LocalStorage.instance.clearSession();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _handleSessionExpired() {
    LocalStorage.instance.clearSession();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
