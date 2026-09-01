import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/menu_permission.dart';

class MenuPermissionRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<RoleMenuPermissions>> getPermissions() async {
    final res = await _client.get(ApiEndpoints.menuPermissions);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => RoleMenuPermissions.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RoleMenuPermissions>> updatePermissions(List<Map<String, dynamic>> updates) async {
    final res = await _client.put(ApiEndpoints.menuPermissions, data: {'updates': updates});
    final list = res['data'] as List<dynamic>;
    return list.map((e) => RoleMenuPermissions.fromJson(e as Map<String, dynamic>)).toList();
  }
}
