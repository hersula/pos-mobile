import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_mobile/data/models/consignment.dart';
import 'package:pos_mobile/main.dart';

void main() {
  testWidgets('PosApp tanpa sesi menampilkan layar login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PosApp());
    await tester.pumpAndSettle();
    expect(find.byType(PosApp), findsOneWidget);
  });

  test('ConsignmentOrder.fromJson memetakan item satuan, summary, dan settlement', () {
    final o = ConsignmentOrder.fromJson({
      'id': 'c1',
      'consignmentNo': 'KNS-20261017-0001',
      'status': 'PARTIALLY_SETTLED',
      'customerId': 'cu1',
      'customer': {'id': 'cu1', 'name': 'Toko Maju'},
      'sourceWarehouseId': 'w1',
      'sourceWarehouse': {'id': 'w1', 'name': 'Gudang Utama'},
      'summary': {'itemCount': 1, 'totalValueSent': '480000', 'totalValueSold': 300000, 'totalValueReturned': 0, 'totalValueRemaining': 180000},
      'items': [
        {
          'id': 'i1',
          'productId': 'p1',
          'product': {'id': 'p1', 'name': 'Air Mineral', 'unit': 'Botol'},
          'unitLabel': 'Dus',
          'conversionQty': 24,
          'qtySent': 2,
          'baseQtySent': 48,
          'baseQtySold': 30,
          'baseQtyReturned': 0,
          'baseQtyRemaining': 18,
          'agreedUnitPrice': '96000',
        }
      ],
      'settlements': [
        {
          'id': 's1',
          'type': 'SALE',
          'voidedAt': null,
          'lines': [
            {'consignmentItemId': 'i1', 'baseQty': 30}
          ]
        }
      ],
    });
    expect(o.summary.totalValueSent, 480000);
    expect(o.items.first.basePrice, 4000);
    expect(o.items.first.displayUnit, 'Dus');
    expect(o.canSettleOrReturn, isTrue);
    expect(o.canCancel, isFalse);
    expect(o.settlements.first.lines.first.baseQty, 30);
  });
}
