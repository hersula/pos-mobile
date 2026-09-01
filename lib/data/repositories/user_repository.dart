import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/app_user.dart';

class UserRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<AppUser>> getUsers() async {
    final res = await _client.get(ApiEndpoints.users);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createUser({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
  }) async {
    await _client.post(ApiEndpoints.users, data: {
      'name': name,
      'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'password': password,
      'role': role,
    });
  }

  Future<void> updateUser(String id, Map<String, dynamic> changes) async {
    await _client.put(ApiEndpoints.userDetail(id), data: changes);
  }

  Future<void> deactivateUser(String id) async {
    await _client.delete(ApiEndpoints.userDetail(id));
  }
}
