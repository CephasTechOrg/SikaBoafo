import 'package:biztrack_gh/features/debts/data/models/local_receivable_record.dart';
import 'package:biztrack_gh/features/debts/presentation/utils/debts_ui_utils.dart';
import 'package:flutter_test/flutter_test.dart';

LocalReceivableRecord _r({
  required String id,
  required String customerId,
  required String status,
  required String outstanding,
}) {
  return LocalReceivableRecord(
    receivableId: id,
    customerId: customerId,
    customerName: 'Test',
    originalAmount: outstanding,
    outstandingAmount: outstanding,
    status: status,
    syncStatus: 'applied',
    createdAtMillis: 0,
  );
}

void main() {
  group('DebtsUiUtils outstanding', () {
    test('sumPortfolioOutstandingMinor ignores settled and cancelled', () {
      final receivables = [
        _r(id: '1', customerId: 'c1', status: 'open', outstanding: '100.00'),
        _r(id: '2', customerId: 'c2', status: 'settled', outstanding: '50.00'),
        _r(id: '3', customerId: 'c1', status: 'cancelled', outstanding: '25.00'),
        _r(
          id: '4',
          customerId: 'c2',
          status: 'partially_paid',
          outstanding: '30.50',
        ),
      ];

      expect(
        DebtsUiUtils.sumPortfolioOutstandingMinor(receivables),
        13050,
      );
    });

    test('customerOutstandingMinor sums only active debts for one customer', () {
      final receivables = [
        _r(id: '1', customerId: 'c1', status: 'open', outstanding: '100.00'),
        _r(id: '2', customerId: 'c2', status: 'open', outstanding: '200.00'),
        _r(id: '3', customerId: 'c1', status: 'settled', outstanding: '40.00'),
      ];

      expect(
        DebtsUiUtils.customerOutstandingMinor('c1', receivables),
        10000,
      );
    });
  });
}
