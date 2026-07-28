import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../models/subscription_status.dart';

class SubscriptionRepository {
  final ApiClient _client = ApiClient.instance;

  Future<TenantSubscriptionStatus> getStatus() async {
    final res = await _client.get(ApiEndpoints.tenantSubscription);
    return TenantSubscriptionStatus.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Upgrade tenant FREE -> SUBSCRIBE, langsung dapat trial 30 hari.
  Future<void> upgradeToSubscribe() async {
    await _client.post(ApiEndpoints.tenantSubscriptionUpgrade);
  }

  /// Ajukan konfirmasi pembayaran perpanjangan langganan ke admin.
  Future<void> requestPayment({String? note}) async {
    await _client.post(ApiEndpoints.tenantSubscriptionRequestPayment, data: {
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }
}
