# UI Polish Guide — Debts & Receivable Detail Screens

## Purpose
Polish the Flutter UI for the Debts dashboard and the Receivable/Debt detail screen so the product feels like a modern financial platform: clean, trustworthy, premium, mobile-first, and visually consistent.

Use the included mockups as the visual source of truth:

- `mockups/01_debts_dashboard_mockup.png`
- `mockups/02_debt_detail_mockup.png`

The goal is not to rebuild business logic. The goal is to improve layout, spacing, color consistency, typography, card styling, and responsive behavior while preserving the existing app architecture.

---

## Files to Focus On

Primary UI files:

- `debts_screen.dart`
- `debt_detail_screen.dart`
- `debts_header.dart`
- `debts_empty_state.dart`
- `debts_search_bar.dart`
- `debts_tab_filter.dart`
- `receive_repayment_screen.dart`

Data/state files to preserve:

- `debts_api.dart`
- `debts_repository.dart`
- `debts_providers.dart`
- `debt_reminders_provider.dart`

Do not rewrite the repository, API, sync queue, Riverpod providers, payment link flow, reminder scheduling, repayment recording, or navigation logic unless a UI change requires a very small integration adjustment.

---

## Overall Design Direction

The screens should feel like a high-trust finance app, similar in polish to Stripe, Revolut, Shopify, or a banking dashboard.

The design should be:

- premium but simple
- spacious but not empty
- highly readable on small Android devices
- consistent across both pages
- green-led, with red used only for risk/destructive states
- soft, rounded, and card-based
- professional enough for merchants and small businesses

Avoid:

- random gradients across unrelated cards
- too many competing icon colors
- overly large decorative shapes that crowd content
- inconsistent border radii
- heavy shadows everywhere
- large sections that push important actions too far down
- changing backend/data logic while polishing UI

---

## Color Palette

Use a tighter, uniform palette across both screens.

Recommended tokens:

```dart
const debtForest900 = Color(0xFF03170A);
const debtForest800 = Color(0xFF052E16);
const debtForest700 = Color(0xFF064E2B);
const debtForest600 = Color(0xFF0F7A3B);
const debtForest500 = Color(0xFF178A4B);

const debtCanvas = Color(0xFFF7F9F7);
const debtSurface = Color(0xFFFFFFFF);
const debtSurfaceAlt = Color(0xFFF2F5F3);
const debtBorder = Color(0xFFE3E8E4);

const debtInk = Color(0xFF111827);
const debtMuted = Color(0xFF6B7280);
const debtMutedSoft = Color(0xFF9CA3AF);

const debtDanger = Color(0xFFDC2626);
const debtDangerSoft = Color(0xFFFEE2E2);
const debtSuccessSoft = Color(0xFFE8F8EF);
```

If `AppColors` already contains equivalent colors, use the existing theme tokens instead of creating duplicates. The key is consistency: deep green for hero/primary actions, white for panels, soft gray for inactive controls, red only for overdue/cancel.

---

## Shared UI Rules

Use consistent radii:

- page white sheet top radius: `32`
- large hero/balance cards: `28`
- standard panels/cards: `22–24`
- buttons/search fields/debt cards: `16–20`
- pills/chips/status badges: `999`

Use consistent spacing:

- screen horizontal padding: `20` on modern phones, fallback `16` on narrow screens
- section spacing: `20–24`
- inside card padding: `18–22`
- compact row spacing: `10–14`
- button height: `52–56`

Use consistent shadows:

- hero cards: soft shadow, low opacity
- list cards: subtle shadow or border, not both heavy
- avoid thick, dark shadows under every element

Use consistent typography:

- screen title: `28–32`, weight `800/900`
- amount hero: `40–48`, weight `800/900`, slight negative letter spacing
- section title: `18–20`, weight `800`
- card title: `15–16`, weight `700/800`
- helper text: `13–14`, muted
- status pill: `12–13`, weight `700`

Keep the cedi symbol consistent everywhere: use `₵`, not a mixture of `GHS`, `$`, and `₵` in the debts UI.

---

## Screen 1 — Debts Dashboard

### Visual Goal
Match `mockups/01_debts_dashboard_mockup.png`.

The screen should read as:

1. Deep green hero summary
2. White rounded content sheet
3. Quick Actions card
4. Debts section with search, filters, and clean debt cards

### Header / Hero
Keep the current `NestedScrollView` + `SliverAppBar` approach if it works well, but refine the visual result.

Requirements:

- Keep the deep green gradient, but simplify it to two or three related green tones.
- Reduce visual noise from decorative icons/shapes. Decorative shapes should be subtle and should never compete with text.
- The header should show:
  - back button
  - `Debts`
  - label: `OUTSTANDING`
  - outstanding amount
  - three compact metric cards: overdue, collected this month, customers
- Metric cards should use translucent green glass styling with a subtle border.
- The amount should dominate the hero.
- Header should not exceed too much height on smaller Android screens.

Suggested hero sizing:

- expanded height: around `230–260`, depending on safe area
- metric card height: `64–72`
- hero amount font: `42–48`

### White Content Sheet
The white content area should feel like a clean bottom sheet rising from the green header.

Requirements:

- Top radius: `32`
- Background: white or very light canvas
- Padding: `20` horizontal, `22–24` top
- Do not let the sheet feel cramped against the hero.

### Quick Actions
The current `New Debt` and `Reports` actions are correct, but polish them.

Requirements:

- Wrap both quick actions in a white elevated panel, as shown in the mockup.
- `New Debt` is primary green.
- `Reports` is muted/soft gray with dark text.
- Both buttons should have the same height and radius.
- Use real icons, not emojis.
- Buttons should feel tappable but not oversized.

Recommended:

- outer panel radius: `24`
- outer panel padding: `14–16`
- button height: `56`
- button radius: `16`

### Debt List Section
Requirements:

- Section title row: `Debts` on the left, search icon on the right.
- Search should remain collapsed by default. Tapping search opens the search field.
- Filter pills: `All`, `Overdue`, `Partial`, `Settled`.
- Active pill: green fill, white text.
- Inactive pills: soft gray fill, border, dark text.
- Debt cards should be clean and horizontally balanced.

Debt card layout:

- avatar/initial on the left
- customer name and due date in the middle
- amount and status pill on the right
- chevron at the far right

Overdue state:

- Use red only for due date, overdue pill, and small avatar text/accent.
- Do not make the entire card red.

Recommended card sizing:

- card radius: `20`
- card padding: `16 horizontal`, `14 vertical`
- avatar: `48x48`
- amount weight: `800`
- status pill: soft background, compact

### Empty State
Keep the current contextual empty state behavior, but restyle it to match the card system.

Requirements:

- large soft icon circle
- title, message
- no harsh borders
- same radius/shadow rules as standard panels

---

## Screen 2 — Receivable / Debt Detail

### Visual Goal
Match `mockups/02_debt_detail_mockup.png`.

The screen should read as:

1. Deep green header with back button, badge, customer name, status
2. Large outstanding balance card
3. Reminders panel
4. Payment actions
5. Customer panel
6. Repayment history panel

### Header
Requirements:

- Use a dark green gradient consistent with the dashboard hero.
- Back button should be clear and aligned.
- `Receivable` badge should be subtle glass style.
- Customer name should be large and bold.
- Status should be visible but not overpowering.
- Avoid large empty header space.

Recommended:

- expanded height: `220–260`
- left/right padding: `20`
- badge height: `34–38`

### Balance Card
The current `_BalanceHero` is a strong starting point. Restyle it to match the mockup more closely.

Requirements:

- Large rounded card with deep green gradient.
- Header row: `Outstanding Balance` + status pill.
- Large amount should be the visual focus.
- Show Original Amount, Paid, Due Date in compact metric cells.
- Use `Wrap`/`LayoutBuilder` for responsiveness.
- On narrow phones, use a 2-column wrap.
- On wider screens, use 3 columns.
- Keep invoice number only if present.

Recommended:

- card radius: `28`
- padding: `22–24`
- amount: `40–46`
- metric tiles: translucent green, soft border, radius `18`

### Reminders Panel
Requirements:

- Use a white card with subtle border and consistent radius.
- Show bell icon, `No reminders set`, and a right-aligned `+ Add Reminder` action.
- When reminders exist, keep the rows clean and compact.
- Do not make this section too tall.

### Payment Actions
Requirements:

- `Receive Payment` must be the primary action.
- Button should be full width, green, height `54–56`, radius `16–18`.
- `Generate Link` and `Cancel Debt` should be side-by-side secondary actions.
- `Generate Link`: neutral/dark text, link icon.
- `Cancel Debt`: red text/icon, but white background.
- Loading state for Generate Link must remain.

Do not remove:

- open repayment bottom sheet flow
- generate link flow
- payment status check flow
- copy link flow
- cancel confirmation flow

### Customer Card
Requirements:

- White card, subtle border, radius `22–24`.
- Header row: `Customer` + optional `Edit` action if edit is implemented.
- Use two-column rows: label left, value right.
- Labels muted, values bold.

Rows:

- Name
- Phone
- Created

### Repayment History
Requirements:

- White card, subtle border, radius `22–24`.
- Header: `Repayment History` + count pill.
- Empty state should be centered, calm, and professional.
- Use a green or blue-gray icon treatment, not strong red/yellow.
- If payments exist, cards should be compact and chronological.

---

## Receive Repayment Screen

The `ReceiveRepaymentScreen` can keep its current structure, but should use the same visual system.

Requirements:

- Header and summary card should use the same green palette.
- Use `₵` instead of `GHS` in display amounts if this screen belongs to the same debts experience.
- Keep bottom save button sticky and full width.
- Input and dropdown fields should share the same radius, border, and height.
- Error panel should be soft, not overly saturated.

---

## Responsiveness Requirements

Test these screen widths:

- 360px Android phone width
- 390px iPhone width
- 430px large phone width

Rules:

- No horizontal overflow.
- No text clipping for customer names; use `maxLines: 1` and ellipsis where needed.
- Primary actions must remain visible without excessive scrolling.
- Hero should not consume more than roughly 40–45% of the first viewport.
- On detail screen, balance + payment actions should be reachable quickly.
- Use `SafeArea`/status bar spacing correctly.
- Avoid hardcoded heights unless necessary.

---

## Implementation Rules for the AI Agent

1. Preserve all existing logic and state management.
2. Polish UI components in place instead of rewriting the whole feature.
3. Extract small reusable widgets only when it improves consistency.
4. Prefer existing `AppColors`, `AppRadii`, and `AppShadows` tokens.
5. If existing tokens are insufficient, add a small local debts UI token section rather than scattering raw colors everywhere.
6. Do not introduce new packages unless absolutely necessary.
7. Do not remove offline-first behavior, sync behavior, providers, payment link generation, reminders, or repayment recording.
8. Keep code readable and maintainable.
9. Use Flutter layout tools properly: `LayoutBuilder`, `Wrap`, `Flexible`, `Expanded`, `SafeArea`, and `MediaQuery` where needed.
10. After implementation, verify loading, empty, error, overdue, partial, settled, and long-name states.

---

## Suggested Work Plan

### Step 1 — Create/normalize debts UI tokens
Add local constants or use theme tokens for:

- green gradient colors
- page background
- card background
- border color
- danger soft color
- common radii
- common shadows

### Step 2 — Polish `DebtsHeader`
Make it match the dashboard mockup:

- cleaner gradient
- larger outstanding amount
- three uniform metric cards
- subtle decorative shape only
- better safe area spacing

### Step 3 — Polish `DebtsScreen`
Focus on:

- white sheet body
- quick action panel
- debt list section spacing
- search placement
- polished debt card
- filter pill consistency

### Step 4 — Polish `DebtDetailScreen`
Focus on:

- header layout
- `_BalanceHero`
- reminders panel
- action buttons
- customer panel
- repayment history panel

### Step 5 — Polish `ReceiveRepaymentScreen`
Only align it with the same design system.

### Step 6 — Validate edge cases
Check:

- no debts
- many debts
- search no results
- overdue debt
- partial debt
- settled debt
- long customer name
- no phone number
- payment link exists
- reminders exist
- offline/pending sync states

---

## Acceptance Criteria

The redesign is complete only when:

- The Debts dashboard visually matches the first mockup direction.
- The Debt Detail screen visually matches the second mockup direction.
- Both pages use a consistent green/white/gray palette.
- Red is limited to overdue/destructive actions.
- The screens feel cleaner, more premium, and more spacious.
- The UI works on small Android devices without awkward spacing or overflow.
- All existing business logic still works.
- The app still supports refresh, search, filters, navigation, reminders, repayment, payment link generation, cancel debt, loading states, error states, and empty states.

