# AI Agent Prompt — Redesign Debts UI

You are working inside a Flutter/Riverpod mobile app. Redesign and polish only the Debts dashboard and Receivable/Debt detail UI based on the included mockups:

- `mockups/01_debts_dashboard_mockup.png`
- `mockups/02_debt_detail_mockup.png`

Read `UI_POLISH_GUIDE.md` first and follow it carefully.

## Main Objective
Make the debts experience look like a premium financial/business app: clean, professional, consistent, responsive, and trustworthy. Keep the green/white/gray palette uniform. Use red only for overdue/destructive states.

## Files to Update
Focus on:

- `debts_screen.dart`
- `debt_detail_screen.dart`
- `debts_header.dart`
- `debts_empty_state.dart`
- `debts_search_bar.dart`
- `debts_tab_filter.dart`
- `receive_repayment_screen.dart`

Do not rewrite these unless absolutely needed:

- `debts_api.dart`
- `debts_repository.dart`
- `debts_providers.dart`
- `debt_reminders_provider.dart`

## Critical Rules

1. Preserve all Riverpod providers, repository calls, API calls, sync behavior, local-first behavior, navigation, and payment/reminder logic.
2. Do not change the meaning of status values such as `open`, `partially_paid`, `settled`, `cancelled`, `overdue`, or `due_soon`.
3. Keep the dashboard structure: green hero, rounded white body, quick actions, debt filters, debt cards.
4. Keep the detail structure: green header, balance card, reminders, payment actions, customer info, repayment history.
5. Make the UI responsive for small Android phones and large phones.
6. Use existing `AppColors`, `AppRadii`, and `AppShadows` where possible. Add local UI tokens only if needed for consistency.
7. Keep the cedi display consistent: use `₵` for amounts in this debts experience.

## Visual Target

Dashboard:

- Deep green hero with `Debts`, `OUTSTANDING`, large total amount, and three compact metric cards.
- White rounded content sheet.
- Elevated Quick Actions panel with `New Debt` primary and `Reports` secondary.
- Clean filters and debt cards.

Detail:

- Deep green header with back button, `Receivable` badge, customer name, status.
- Large premium balance card.
- Clean reminders card.
- Full-width `Receive Payment` button.
- Side-by-side `Generate Link` and `Cancel Debt` buttons.
- Clean customer card and repayment history card.

## Final Checks

Before finishing, test visually for:

- small screen spacing
- long customer names
- empty debts
- search results and no results
- overdue state
- settled/partial/cancelled states
- loading/error states
- payment link generated state
- reminders empty and non-empty state

Do not stop after only changing colors. This is a full UI polish pass: layout, spacing, typography, cards, buttons, filters, and responsive behavior all need attention.
