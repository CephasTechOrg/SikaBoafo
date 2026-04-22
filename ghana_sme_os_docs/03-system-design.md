# System Design

## Main System Flows

### 1. Merchant Onboarding Flow
1. Merchant creates account
2. Merchant creates business profile
3. Merchant adds first staff member if needed
4. Merchant adds first products
5. Merchant connects Paystack
6. Merchant configures notification settings
7. Merchant starts recording sales and invoices

### 2. Product and Inventory Flow
1. Merchant adds product
2. Product gets SKU, stock quantity, cost price, selling price, reorder level
3. Stock changes only through controlled actions:
   - stock received
   - sale completed
   - return recorded
   - damaged goods recorded
   - approved manual adjustment
4. Every stock change writes an inventory movement record

### 3. Sale Flow
1. Cashier selects products
2. System computes total
3. Customer chosen or created
4. Merchant selects payment mode:
   - paid now
   - part payment
   - credit / invoice
5. If paid now, sale can be linked to payment request
6. On successful payment, sale status becomes paid
7. Stock is reduced
8. Receipt is sent

### 4. Credit / Debt Flow
1. Merchant records a sale for a customer
2. Full or part amount remains unpaid
3. System creates invoice and outstanding balance
4. Customer receives invoice/reminder through WhatsApp or SMS
5. Customer opens payment link
6. Provider processes payment
7. Webhook notifies backend
8. Invoice status updates
9. Customer balance updates
10. Receipt/confirmation is sent

### 5. Daily Summary Flow
1. End-of-day job runs
2. System calculates:
   - total sales
   - unpaid balances
   - low stock items
   - top products
   - staff activity
3. Summary is sent to owner

## User Roles

### Owner
Can:
- manage business settings
- connect payment provider
- add/remove workers
- see all sales
- see debts
- see reports
- approve sensitive actions
- inspect audit logs

### Manager
Can:
- view business or branch operations
- manage stock
- manage workers where allowed
- view reports
- approve selected workflows

### Cashier
Can:
- create sales
- create invoices
- request payments
- view allowed customers/products
- issue receipts
- cannot manage all system settings

### Stock Keeper
Can:
- receive stock
- adjust stock with reason
- see low stock items
- cannot approve payment settings

## Messaging Design

### Smartphone path
- message via WhatsApp
- payment link opens hosted checkout

### Basic phone path
- message via SMS
- payment instructions support provider-supported offline/USSD-friendly flows where available

The system should choose message channel based on:
- customer phone capability if known
- customer preference if known
- merchant settings
- fallback rules

## Trust and Accountability Features
- every sale tied to a staff user
- every stock edit tied to a staff user
- invoice history retained
- reminder history retained
- payment reference history retained
- suspicious or repeated cancellations visible to owner

## Version 1 Product Boundary
Version 1 should not include:
- advanced accounting
- tax filing automation
- multi-provider payment complexity
- complex lending workflows
- marketplace settlement logic
- direct handling of merchant funds

Keep version 1 operational and reliable.
