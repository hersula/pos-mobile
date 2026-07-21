import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/num_parser.dart';

class SalesSummary {
  final int totalTransactions;
  final num totalGrossSales;
  final num totalDiscount;
  final num totalTax;
  final num totalNetSales;
  final num totalOutstanding;
  final Map<String, num> byPaymentMethod;

  SalesSummary({
    required this.totalTransactions,
    required this.totalGrossSales,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalNetSales,
    required this.totalOutstanding,
    required this.byPaymentMethod,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final byMethodJson = (json['byPaymentMethod'] as Map<String, dynamic>?) ?? {};
    return SalesSummary(
      totalTransactions: parseInt(json['totalTransactions']),
      totalGrossSales: parseNum(json['totalGrossSales']),
      totalDiscount: parseNum(json['totalDiscount']),
      totalTax: parseNum(json['totalTax']),
      totalNetSales: parseNum(json['totalNetSales']),
      totalOutstanding: parseNum(json['totalOutstanding']),
      byPaymentMethod: byMethodJson.map((k, v) => MapEntry(k, parseNum(v))),
    );
  }
}

class ProfitLossAccount {
  final String code;
  final String name;
  final num amount;

  ProfitLossAccount({required this.code, required this.name, required this.amount});

  factory ProfitLossAccount.fromJson(Map<String, dynamic> json) {
    return ProfitLossAccount(code: json['code'] as String, name: json['name'] as String, amount: parseNum(json['amount']));
  }
}

class ProfitLossReport {
  final List<ProfitLossAccount> revenueAccounts;
  final num totalRevenue;
  final num costOfGoodsSold;
  final num grossProfit;
  final List<ProfitLossAccount> expenseAccounts;
  final num totalOperatingExpenses;
  final num netProfit;
  final num totalPurchasesInPeriod;
  final num accountsPayableBalance;

  ProfitLossReport({
    required this.revenueAccounts,
    required this.totalRevenue,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.expenseAccounts,
    required this.totalOperatingExpenses,
    required this.netProfit,
    this.totalPurchasesInPeriod = 0,
    this.accountsPayableBalance = 0,
  });

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue'] as Map<String, dynamic>;
    final opex = json['operatingExpenses'] as Map<String, dynamic>;
    final additionalInfo = json['additionalInfo'] as Map<String, dynamic>?;

    return ProfitLossReport(
      revenueAccounts: (revenue['accounts'] as List<dynamic>)
          .map((e) => ProfitLossAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalRevenue: parseNum(revenue['total']),
      costOfGoodsSold: parseNum(json['costOfGoodsSold']),
      grossProfit: parseNum(json['grossProfit']),
      expenseAccounts:
          (opex['accounts'] as List<dynamic>).map((e) => ProfitLossAccount.fromJson(e as Map<String, dynamic>)).toList(),
      totalOperatingExpenses: parseNum(opex['total']),
      netProfit: parseNum(json['netProfit']),
      totalPurchasesInPeriod: parseNum(additionalInfo?['totalPurchasesInPeriod']),
      accountsPayableBalance: parseNum(additionalInfo?['accountsPayableBalance']),
    );
  }
}

class OutstandingDebt {
  final String id;
  final String poNumber;
  final String? supplierName;
  final num total;
  final num paidAmount;
  final num outstanding;
  final DateTime createdAt;

  OutstandingDebt({
    required this.id,
    required this.poNumber,
    this.supplierName,
    required this.total,
    required this.paidAmount,
    required this.outstanding,
    required this.createdAt,
  });

  factory OutstandingDebt.fromJson(Map<String, dynamic> json) {
    return OutstandingDebt(
      id: json['id'] as String,
      poNumber: json['poNumber'] as String,
      supplierName: json['supplierName'] as String?,
      total: parseNum(json['total']),
      paidAmount: parseNum(json['paidAmount']),
      outstanding: parseNum(json['outstanding']),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class PurchasesSummary {
  final int totalTransactions;
  final num totalPurchases;
  final Map<String, num> byPaymentMethod;
  final num totalOutstandingDebt;
  final List<OutstandingDebt> outstandingDebts;

  PurchasesSummary({
    required this.totalTransactions,
    required this.totalPurchases,
    required this.byPaymentMethod,
    required this.totalOutstandingDebt,
    required this.outstandingDebts,
  });

  factory PurchasesSummary.fromJson(Map<String, dynamic> json) {
    final byMethodJson = (json['byPaymentMethod'] as Map<String, dynamic>?) ?? {};
    final debtsJson = (json['outstandingDebts'] as List<dynamic>?) ?? [];
    return PurchasesSummary(
      totalTransactions: parseInt(json['totalTransactions']),
      totalPurchases: parseNum(json['totalPurchases']),
      byPaymentMethod: byMethodJson.map((k, v) => MapEntry(k, parseNum(v))),
      totalOutstandingDebt: parseNum(json['totalOutstandingDebt']),
      outstandingDebts: debtsJson.map((e) => OutstandingDebt.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ReportRepository {
  final ApiClient _client = ApiClient.instance;

  Future<SalesSummary> getSalesSummary({String? dateFrom, String? dateTo}) async {
    final res = await _client.get(ApiEndpoints.reportSalesSummary, query: {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    return SalesSummary.fromJson(res);
  }

  Future<ProfitLossReport> getProfitLoss({String? dateFrom, String? dateTo}) async {
    final res = await _client.get(ApiEndpoints.reportProfitLoss, query: {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    return ProfitLossReport.fromJson(res);
  }

  Future<PurchasesSummary> getPurchasesSummary({String? dateFrom, String? dateTo}) async {
    final res = await _client.get(ApiEndpoints.reportPurchasesSummary, query: {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    return PurchasesSummary.fromJson(res);
  }
}
