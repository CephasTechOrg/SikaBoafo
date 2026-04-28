/// Compile-time config via `--dart-define`.
/// Example: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
class AppConfig {
  AppConfig._();

  static const bool _isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _isReleaseBuild
        ? 'https://biztrackgh-api.onrender.com'
        : 'http://127.0.0.1:8000',
  );

  static const String apiV1Prefix = '/api/v1';

  // Supabase — only the public anon key is used on the client.
  // Pass at build time: --dart-define=SUPABASE_ANON_KEY=<key>
  static const String supabaseUrl = 'https://eeexkzdlptrlqtgqdnfm.supabase.co';
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // Storage bucket and folder names.
  static const String supabaseBucket = 'SikaBoafo';
  static const String supabaseProductsFolder = 'Products';
  static const String supabaseUserUploadsFolder = 'UserUploads';

  static Uri apiRoot() => Uri.parse(apiBaseUrl);

  static Uri apiV1(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiBaseUrl$apiV1Prefix$p');
  }
}
