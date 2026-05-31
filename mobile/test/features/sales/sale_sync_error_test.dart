import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/sales/utils/sale_sync_error.dart';

void main() {
  group('humanizeSaleSyncError', () {
    test('surfaces StateError message instead of inventory fallback', () {
      expect(
        humanizeSaleSyncError(
          StateError('Item not found for store: abc-123'),
        ),
        'Item not found for store: abc-123',
      );
    });

    test('parses FastAPI list validation detail on DioException', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/sync/apply'),
        response: Response(
          requestOptions: RequestOptions(path: '/sync/apply'),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'operations', 0, 'payload'],
                'msg': 'Field required',
                'type': 'missing',
              },
            ],
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(humanizeSaleSyncError(error), 'Field required');
    });

    test('does not return generic inventory copy for unknown errors', () {
      expect(
        humanizeSaleSyncError(Exception('sqlite busy')),
        isNot(contains('Inventory request failed')),
      );
    });
  });
}
