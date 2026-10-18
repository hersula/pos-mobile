import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/stock_opname.dart';
import 'package:pos_mobile/data/repositories/stock_opname_repository.dart';

void main() {
  test('StockOpname.fromJson memetakan header, summary, dan item', () {
    final o = StockOpname.fromJson({
      'id': 'o1',
      'opnameNo': 'OPN-20261018-0001',
      'status': 'DRAFT',
      'warehouseId': 'w1',
      'warehouse': {'id': 'w1', 'name': 'Gudang Utama'},
      'categoryId': null,
      'summary': {
        'totalItems': 2,
        'countedItems': 1,
        'surplusQty': 0,
        'shortageQty': 2,
        'surplusValue': 0,
        'shortageValue': '20000',
        'netValue': -20000,
      },
      'items': [
        {
          'id': 'i1',
          'productId': 'p1',
          'product': {'id': 'p1', 'name': 'Kopi', 'sku': 'KP01', 'barcode': '899', 'unit': 'pcs'},
          'systemQty': 10,
          'countedQty': 8,
          'unitCost': '10000',
          'diffValue': -20000,
        },
        {
          'id': 'i2',
          'productId': 'p2',
          'product': {'id': 'p2', 'name': 'Teh', 'sku': null, 'barcode': null, 'unit': 'pcs'},
          'systemQty': 5,
          'countedQty': null,
        },
      ],
    });
    expect(o.isDraft, true);
    expect(o.warehouseName, 'Gudang Utama');
    expect(o.summary.shortageValue, 20000);
    expect(o.summary.netValue, -20000);
    expect(o.items[0].diff, -2);
    expect(o.items[0].unitCost, 10000);
    expect(o.items[1].counted, false);
    expect(o.items[1].diff, isNull);
    expect(o.items[0].withCounted(12).diffValue, 20000);
  });

  test('parseConflictItems membaca details.items STOCK_CONFLICT', () {
    final items = parseConflictItems({
      'code': 'STOCK_CONFLICT',
      'details': {
        'items': [
          {'itemId': 'i1', 'productId': 'p1', 'productName': 'Kopi', 'currentQty': 1, 'diff': -3},
        ],
      },
    });
    expect(items.length, 1);
    expect(items.first.productName, 'Kopi');
    expect(items.first.diff, -3);
    expect(parseConflictItems(null), isEmpty);
  });

  test('fmtQty membuang .0', () {
    expect(fmtQty(3.0), '3');
    expect(fmtQty(2.5), '2.5');
  });
}
