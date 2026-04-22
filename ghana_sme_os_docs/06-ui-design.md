# UI Design Prompt and Product UX Notes

## Product UX Direction
Design a Ghana-first business operations app for small merchants such as pharmacies, provision stores, electrical shops, building material sellers, fashion wholesalers, and agro-input stores.

The app should feel:
- simple
- trustworthy
- professional
- modern but not complicated
- efficient for daily use
- optimized for Android-first usage

## Visual Tone
- clean white surfaces
- strong blue primary brand
- subtle green success/payment accents
- warm neutral grays
- bold but readable headings
- large touch targets
- clear data hierarchy

## UX Principles
- reduce typing
- use smart defaults
- keep flows short
- make money state obvious
- make stock state obvious
- make debt state obvious
- avoid accounting jargon
- prioritize speed for daily operations

## Main Screens Needed

### 1. Onboarding
- create account
- create business
- select business type
- connect payments
- add first products
- add first staff member

### 2. Dashboard
Show:
- sales today
- unpaid balances
- low stock count
- top selling items
- staff activity summary
- quick actions

Quick actions:
- New Sale
- New Invoice
- Record Stock
- Send Reminder
- Add Customer

### 3. Sales Screen
- product search
- add items
- customer selection
- total amount
- payment mode
- pay now / pay later
- send receipt

### 4. Invoice / Debt Screen
- customer name
- outstanding balances
- due date
- send reminder
- payment status
- payment history

### 5. Inventory Screen
- products list
- current stock
- reorder warnings
- stock movement history
- add stock
- adjust stock with reason

### 6. Customers Screen
- customer list
- phone number
- total owed
- recent payments
- preferred contact channel
- send payment reminder

### 7. Staff Screen
- owner / manager / cashier / stock keeper roles
- activity visibility
- permission summaries

### 8. Payment Settings
- Connect Paystack
- connection status
- verify account
- finish setup
- test payment
- message explaining simple merchant-owned payment model

## Payment UX
When showing payment actions:
- emphasize "Send payment link"
- emphasize "Receive by MoMo"
- show payment status badge clearly
- do not expose raw gateway technical terms to the merchant

## Message UX Examples

### Reminder card
- Customer: Kojo Mensah
- Owes: GHS 300
- Due: Today
- Action: Send WhatsApp Reminder
- Secondary action: Send SMS

### Receipt card
- Paid successfully
- Amount
- Channel
- Reference
- Sent to customer

## UI Prompt For Designer / AI Tool
Design a mobile-first Ghanaian SME business operations app called "MoMoLedger" or "MikaOS". The app should help merchants track sales, inventory, debts, customer payments, and staff activity. It must support mobile money payment links, WhatsApp reminders, low-stock alerts, simple reports, and role-based access for owners, managers, cashiers, and stock keepers. The design should feel clean, premium, highly usable, and trustworthy. Prioritize fast checkout, obvious payment status, visible customer balances, and low-stock warnings. Use a blue-and-white color system with subtle green accents for successful payments and collections. Keep the dashboard extremely useful and action-driven. Avoid clutter and avoid heavy accounting complexity. The product should feel built specifically for Ghanaian small businesses.

## UX Anti-Patterns To Avoid
- cluttered dashboards
- tiny text
- too many accounting terms
- hidden debt information
- hidden stock warnings
- technical payment jargon
- long onboarding forms
- poor contrast or tiny buttons
