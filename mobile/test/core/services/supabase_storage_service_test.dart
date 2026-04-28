import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/supabase_storage_service.dart';

void main() {
  group('SupabaseStorageService.labelFromFilename', () {
    test('strips extension and title-cases words', () {
      expect(
        SupabaseStorageService.labelFromFilename('coca_cola.png'),
        'Coca Cola',
      );
    });

    test('handles hyphens as word separators', () {
      expect(
        SupabaseStorageService.labelFromFilename('malt-drink.jpg'),
        'Malt Drink',
      );
    });

    test('handles mixed underscores and hyphens', () {
      expect(
        SupabaseStorageService.labelFromFilename('indomie_instant-noodles.png'),
        'Indomie Instant Noodles',
      );
    });

    test('collapses consecutive separators', () {
      expect(
        SupabaseStorageService.labelFromFilename('fan__ice.jpg'),
        'Fan Ice',
      );
    });

    test('handles file with no extension', () {
      expect(
        SupabaseStorageService.labelFromFilename('peak_milk'),
        'Peak Milk',
      );
    });

    test('single word filename', () {
      expect(
        SupabaseStorageService.labelFromFilename('milk.jpg'),
        'Milk',
      );
    });

    test('lowercases everything except first letter of each word', () {
      expect(
        SupabaseStorageService.labelFromFilename('COCA_COLA.PNG'),
        'Coca Cola',
      );
    });

    test('treats dots in basename as word separators', () {
      expect(
        SupabaseStorageService.labelFromFilename('peak.milk.jpg'),
        'Peak Milk',
      );
    });
  });
}
