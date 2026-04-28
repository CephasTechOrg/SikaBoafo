import 'dart:typed_data';

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

class SupabaseStorageService {
  SupabaseStorageService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  /// Lists all files under [AppConfig.supabaseProductsFolder] in the bucket.
  Future<List<StorageProduct>> listOfficialProducts() async {
    final files = await _client.storage
        .from(AppConfig.supabaseBucket)
        .list(path: AppConfig.supabaseProductsFolder);

    final products = <StorageProduct>[];
    for (final file in files) {
      // Skip folder placeholder files.
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
        label: _labelFromFilename(file.name),
        publicUrl: url,
      ));
    }
    return products;
  }

  /// Uploads [bytes] to UserUploads/{userId}/{filename} and returns the public URL.
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

  String _labelFromFilename(String filename) {
    // Strip extension, replace separators with spaces, title-case.
    final noExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    return noExt
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }
}
