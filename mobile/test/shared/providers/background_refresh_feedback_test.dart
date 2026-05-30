import 'package:biztrack_gh/app/navigation_keys.dart';
import 'package:biztrack_gh/shared/providers/background_refresh_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MOB-03: background refresh failure shows deduped snackbar',
      (tester) async {
    final feedback = BackgroundRefreshFeedback();

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    feedback.reportFailure(
      scope: BackgroundRefreshScope.debts,
      message: 'Backend unreachable.',
    );
    await tester.pump();
    expect(find.text('Debts refresh failed: Backend unreachable.'), findsOneWidget);

    feedback.reportFailure(
      scope: BackgroundRefreshScope.debts,
      message: 'Backend unreachable.',
    );
    await tester.pump();
    expect(find.text('Debts refresh failed: Backend unreachable.'), findsOneWidget);
  });

  testWidgets('MOB-03: user-initiated refresh does not show snackbar',
      (tester) async {
    final feedback = BackgroundRefreshFeedback();

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    feedback.reportFailure(
      scope: BackgroundRefreshScope.debts,
      message: 'Backend unreachable.',
      userInitiated: true,
    );
    await tester.pump();
    expect(find.textContaining('Debts refresh failed'), findsNothing);
  });
}
