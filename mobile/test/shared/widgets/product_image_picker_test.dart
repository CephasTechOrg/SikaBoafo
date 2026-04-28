import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/supabase_storage_service.dart';
import 'package:biztrack_gh/shared/providers/storage_providers.dart';
import 'package:biztrack_gh/shared/widgets/product_image_catalog.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeStorageService implements StorageService {
  _FakeStorageService({this.products = const []});

  final List<StorageProduct> products;
  String? lastUploadedUserId;
  String? lastUploadedFilename;

  @override
  Future<List<StorageProduct>> listOfficialProducts() async => products;

  @override
  Future<String> uploadUserImage({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    lastUploadedUserId = userId;
    lastUploadedFilename = filename;
    return 'https://fake.supabase.co/uploaded/$filename';
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildPicker({
  String? selected,
  required ValueChanged<String?> onChanged,
  StorageService? storageService,
  List<StorageProduct> catalogProducts = const [],
}) {
  final svc = storageService ??
      _FakeStorageService(products: catalogProducts);
  return ProviderScope(
    overrides: [
      supabaseStorageServiceProvider.overrideWithValue(svc),
      officialProductsProvider.overrideWith(
        (_) async => catalogProducts,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ProductImagePicker(
          selected: selected,
          onChanged: onChanged,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ProductImagePicker', () {
    testWidgets('renders label, catalog button and upload button',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildPicker(selected: null, onChanged: (_) {}),
      );
      await tester.pump();

      expect(find.text('PRODUCT IMAGE'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Upload photo'), findsOneWidget);
    });

    testWidgets('remove button is hidden when no image is selected',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildPicker(selected: null, onChanged: (_) {}),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('remove button is visible when an image is selected',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildPicker(
          selected: 'https://example.com/image.jpg',
          onChanged: (_) {},
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('tapping remove calls onChanged with null', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? result = 'https://example.com/image.jpg';
      await tester.pumpWidget(
        _buildPicker(
          selected: result,
          onChanged: (v) => result = v,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('tapping Catalog opens product catalog sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildPicker(
          selected: null,
          onChanged: (_) {},
          catalogProducts: [
            const StorageProduct(
              name: 'coca_cola.png',
              label: 'Coca Cola',
              publicUrl: 'https://example.com/coca_cola.png',
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Catalog'));
      // Pump through sheet open animation + FutureProvider resolution.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Product Catalog'), findsOneWidget);
    });

    testWidgets('selecting a product from catalog calls onChanged with URL',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selectedUrl;
      const productUrl = 'https://example.com/coca_cola.png';

      await tester.pumpWidget(
        _buildPicker(
          selected: null,
          onChanged: (v) => selectedUrl = v,
          catalogProducts: [
            const StorageProduct(
              name: 'coca_cola.png',
              label: 'Coca Cola',
              publicUrl: productUrl,
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Catalog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Coca Cola'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(selectedUrl, equals(productUrl));
    });

    testWidgets('tapping Upload photo opens source picker sheet',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildPicker(selected: null, onChanged: (_) {}),
      );
      await tester.pump();

      await tester.tap(find.text('Upload photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
    });
  });
}
