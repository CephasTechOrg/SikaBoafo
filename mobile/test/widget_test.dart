import 'package:flutter_test/flutter_test.dart';
import 'package:biztrack_gh/app/theme/app_theme.dart';

void main() {
  test('App theme builds', () {
    final theme = buildAppTheme();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary.toARGB32(), isNot(0));
  });
}
