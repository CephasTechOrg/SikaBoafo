import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env/app_config.dart';

class StorageProduct {
  const StorageProduct({
    required this.name,
    required this.label,
    required this.publicUrl,
  });

  final String name;
  final String label;
  final String publicUrl;
}

/// Contract implemented by [SupabaseStorageService] and fakes used in tests.
abstract class StorageService {
  Future<List<StorageProduct>> listOfficialProducts();
  Future<String> uploadUserImage({
    required String userId,
    required Uint8List bytes,
    required String filename,
  });
}

class SupabaseStorageService implements StorageService {
  SupabaseStorageService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<StorageProduct>> listOfficialProducts() async {
    final files = await _client.storage
        .from(AppConfig.supabaseBucket)
        .list(path: AppConfig.supabaseProductsFolder);

    final products = <StorageProduct>[];
    for (final file in files) {
      if (file.name == '.emptyFolderPlaceholder' ||
          file.name.startsWith('.')) {
        continue;
      }

      final storagePath =
          '${AppConfig.supabaseProductsFolder}/${file.name}';
      final url = _client.storage
          .from(AppConfig.supabaseBucket)
          .getPublicUrl(storagePath);

      products.add(StorageProduct(
        name: file.name,
        label: labelFromFilename(file.name),
        publicUrl: url,
      ));
    }
    return products;
  }

  @override
  Future<String> uploadUserImage({
    required String userId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final storagePath =
        '${AppConfig.supabaseUserUploadsFolder}/$userId/$filename';
    await _client.storage.from(AppConfig.supabaseBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage
        .from(AppConfig.supabaseBucket)
        .getPublicUrl(storagePath);
  }

  /// Converts a storage filename to a display label.
  /// Exposed for testing.
  @visibleForTesting
  static String labelFromFilename(String filename) {
    final noExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    return noExt
        .replaceAll(RegExp(r'[_\-\.]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
