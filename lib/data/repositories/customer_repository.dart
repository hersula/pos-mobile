import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/customer.dart';

class CustomerRepository {
  final ApiClient _client = ApiClient.instance;

  Future<List<Customer>> getCustomers({String? search}) async {
    final res = await _client.get(ApiEndpoints.customers, query: {
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = res['data'] as List<dynamic>;
    return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Customer> createCustomer({required String name, String? phone, String? email}) async {
    final res = await _client.post(ApiEndpoints.customers, data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return Customer.fromJson(res['data'] as Map<String, dynamic>);
  }
}
