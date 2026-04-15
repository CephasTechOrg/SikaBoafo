import 'package:biztrack_gh/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BizTrackApp builds', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BizTrackApp()),
    );
    expect(find.text('BizTrack GH'), findsOneWidget);
  });
}
