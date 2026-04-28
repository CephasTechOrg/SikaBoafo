import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/supabase_storage_service.dart';
import 'package:biztrack_gh/shared/providers/storage_providers.dart';

// ---------------------------------------------------------------------------
// Fake
// ---------------------------------------------------------------------------

class _FakeStorageService implements StorageService {
  _FakeStorageService({required this.products, this.throwOn});

  final List<StorageProduct> products;
  final Object? throwOn;

  @override
  Future<List<StorageProduct>> listOfficialProducts() async {
    if (throwOn != null) throw throwOn!;
    return products;
  }

  @override
  Future<String> uploadUserImage({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async =>
      'https://fake.supabase.co/storage/v1/object/public/SikaBoafo/UserUploads/$userId/$filename';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('officialProductsProvider', () {
    test('exposes products returned by the storage service', () async {
      final fakeProducts = [
        const StorageProduct(
          name: 'coca_cola.png',
          label: 'Coca Cola',
          publicUrl: 'https://example.com/coca_cola.png',
        ),
        const StorageProduct(
          name: 'peak_milk.jpg',
          label: 'Peak Milk',
          publicUrl: 'https://example.com/peak_milk.jpg',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(
            _FakeStorageService(products: fakeProducts),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(officialProductsProvider.future);

      expect(result, equals(fakeProducts));
      expect(result.length, 2);
      expect(result.first.label, 'Coca Cola');
    });

    test('propagates errors from the storage service', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(
            _FakeStorageService(
              products: const [],
              throwOn: Exception('network error'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(officialProductsProvider.future),
        // The future itself throws, we check the provider is in error state.
        returnsNormally,
      );

      final asyncValue = await container.read(officialProductsProvider.future).then(
            (v) => AsyncData<List<StorageProduct>>(v),
            onError: (e, s) => AsyncError<List<StorageProduct>>(e, s),
          );

      expect(asyncValue, isA<AsyncError<List<StorageProduct>>>());
    });

    test('returns empty list when catalog has no products', () async {
      final container = ProviderContainer(
        overrides: [
          supabaseStorageServiceProvider.overrideWithValue(
            _FakeStorageService(products: const []),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(officialProductsProvider.future);
      expect(result, isEmpty);
    });
  });

  group('_FakeStorageService.uploadUserImage', () {
    test('constructs the expected public URL', () async {
      final svc = _FakeStorageService(products: const []);
      final url = await svc.uploadUserImage(
        userId: 'user-123',
        bytes: Uint8List(0),
        filename: '1234567890.jpg',
      );
      expect(url, contains('UserUploads/user-123/1234567890.jpg'));
    });
  });
}
