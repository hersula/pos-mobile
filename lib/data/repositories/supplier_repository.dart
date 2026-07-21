import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/supplier.dart';

class SupplierRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Supplier>> getSuppliers() async {
    final res = await _client.get(ApiEndpoints.suppliers);
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Supplier> createSupplier({required String name, String? phone, String? address}) async {
    final res = await _client.post(ApiEndpoints.suppliers, data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
    });
    return Supplier.fromJson(res['data'] as Map<String, dynamic>);
  }
}
