import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global test setup. Forces google_fonts to use the bundled assets only, so
/// tests never attempt a (failing) network fetch for Plus Jakarta Sans.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
