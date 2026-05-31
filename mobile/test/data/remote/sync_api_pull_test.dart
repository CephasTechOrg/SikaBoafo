import 'package:biztrack_gh/data/remote/sync_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SyncPullResult parses cursor and domain rows', () {
    final result = SyncPullResult.fromJson({
      'cursor': '2026-05-29T12:00:00.123456Z',
      'full_refresh': false,
      'inventory': [
        {'item_id': 'item-1', 'name': 'Sugar', 'default_price': '10.00'},
      ],
      'customers': [
        {
          'customer_id': 'cust-1',
          'name': 'Ama',
          'total_outstanding': '0.00',
          'created_at': '2026-01-01T00:00:00Z',
        },
      ],
      'receivables': [],
    });

    expect(result.fullRefresh, isFalse);
    expect(result.inventory, hasLength(1));
    expect(result.customers, hasLength(1));
    expect(result.receivables, isEmpty);
    expect(result.cursor.isUtc, isTrue);
  });
}
