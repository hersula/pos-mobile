import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/core/api/api_exception.dart';
import 'package:pos_mobile/features/consignment/consignment_receivables.dart';

void main() {
  test('validatePaymentAmount', () {
    expect(validatePaymentAmount('', 1000), isNotNull);
    expect(validatePaymentAmount('0', 1000), isNotNull);
    expect(validatePaymentAmount('abc', 1000), isNotNull);
    expect(validatePaymentAmount('1000.5', 1000), contains('Melebihi'));
    expect(validatePaymentAmount('1001', 1000), contains('Melebihi'));
    expect(validatePaymentAmount('1000', 1000), isNull);
    expect(validatePaymentAmount('250,5', 1000), isNull);
  });

  test('paymentErrorMessage memberi pesan coba lagi untuk CONCURRENT_UPDATE', () {
    final e = ApiException('x', statusCode: 409, data: {'code': 'CONCURRENT_UPDATE'});
    expect(paymentErrorMessage(e), contains('coba lagi'));
    expect(paymentErrorMessage(ApiException('Gagal', statusCode: 500)), 'Gagal');
  });

  test('metode bayar sesuai enum kontrak', () {
    expect(kSalePaymentMethods.keys.toSet(), {'CASH', 'DEBIT', 'CREDIT', 'QRIS', 'TRANSFER', 'EWALLET'});
  });
}
