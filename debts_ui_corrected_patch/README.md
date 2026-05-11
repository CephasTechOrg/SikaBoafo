# Correct Debts UI Patch

Copy these files into the exact matching paths in your Flutter project:

1. `lib/features/debts/presentation/debt_detail_screen.dart`
2. `lib/features/debts/presentation/debts_screen.dart`
3. `lib/features/debts/presentation/receive_repayment_screen.dart`
4. `lib/features/debts/presentation/utils/debts_ui_tokens.dart`

Why `receive_repayment_screen.dart` is included:
Your analyzer output shows a test importing `package:biztrack_gh/features/debts/presentation/receive_repayment_screen.dart`. So even if the current UI opens the repayment form from `debt_detail_screen.dart`, this file still needs to exist at the presentation root path for tests/build references.

This patch is UI-only. It does not change API, repository, providers, sync, database, payment logic, or backend behavior.
