import '../../core/utils/num_parser.dart';

class SubscriptionDetail {
  final String id;
  final String planName;
  final String status; // TRIAL | ACTIVE | PENDING_PAYMENT | EXPIRED | CANCELLED
  final String paymentStatus; // UNPAID | PAID
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final bool isExpired;

  SubscriptionDetail({
    required this.id,
    required this.planName,
    required this.status,
    required this.paymentStatus,
    required this.startDate,
    required this.endDate,
    required this.daysRemaining,
    required this.isExpired,
  });

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetail(
      id: json['id'] as String,
      planName: json['planName'] as String? ?? '-',
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      daysRemaining: parseInt(json['daysRemaining']),
      isExpired: json['isExpired'] as bool? ?? false,
    );
  }
}

class TenantSubscriptionStatus {
  final String planType; // FREE | SUBSCRIBE
  final int? dailyTransactionUsed;
  final int? dailyTransactionLimit;
  final int? dailyTransactionRemaining;
  final SubscriptionDetail? subscription;

  TenantSubscriptionStatus({
    required this.planType,
    this.dailyTransactionUsed,
    this.dailyTransactionLimit,
    this.dailyTransactionRemaining,
    this.subscription,
  });

  bool get isFree => planType == 'FREE';
  bool get isSubscribe => planType == 'SUBSCRIBE';

  factory TenantSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return TenantSubscriptionStatus(
      planType: json['planType'] as String,
      dailyTransactionUsed: json['dailyTransactionUsed'] != null ? parseInt(json['dailyTransactionUsed']) : null,
      dailyTransactionLimit: json['dailyTransactionLimit'] != null ? parseInt(json['dailyTransactionLimit']) : null,
      dailyTransactionRemaining:
          json['dailyTransactionRemaining'] != null ? parseInt(json['dailyTransactionRemaining']) : null,
      subscription: json['subscription'] != null ? SubscriptionDetail.fromJson(json['subscription'] as Map<String, dynamic>) : null,
    );
  }
}
