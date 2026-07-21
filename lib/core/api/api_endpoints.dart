class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const registerTenant = '/auth/register-tenant';
  static const login = '/auth/login';
  static const refresh = '/auth/refresh';

  // Master data
  static const categories = '/categories';
  static const warehouses = '/warehouses';
  static const products = '/products';
  static const suppliers = '/suppliers';
  static const customers = '/customers';

  // Inventori
  static const stocks = '/stocks';
  static const stockMovements = '/stock-movements';
  static const purchaseOrders = '/purchase-orders';
  static String purchaseOrderDetail(String id) => '/purchase-orders/$id';
  static String purchaseOrderReceive(String id) => '/purchase-orders/$id/receive';

  // Penjualan
  static const sales = '/sales';
  static String saleDetail(String id) => '/sales/$id';
  static String saleCancel(String id) => '/sales/$id/cancel';
  static String salePayments(String id) => '/sales/$id/payments';

  // Akunting
  static const chartOfAccounts = '/accounting/chart-of-accounts';
  static const journal = '/accounting/journal';
  static const ledger = '/accounting/ledger';
  static const expenses = '/expenses';

  // Laporan
  static const reportSalesSummary = '/reports/sales-summary';
  static const reportProfitLoss = '/reports/profit-loss';
}
