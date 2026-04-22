# Database Design

## Design Principles
- multi-tenant by business_id
- normalized enough for correctness
- audit-ready
- payment reference tracking
- event-driven inventory movement
- explicit role and permission structure

## Core Tables

### businesses
- id
- name
- type
- phone
- whatsapp_number
- email
- address
- city
- region
- country
- currency_code
- created_at
- updated_at

### users
- id
- business_id
- full_name
- phone
- email
- password_hash
- is_active
- last_login_at
- created_at
- updated_at

### roles
- id
- name
- description

### user_roles
- id
- user_id
- role_id
- business_id
- created_at

### customers
- id
- business_id
- full_name
- phone
- whatsapp_number
- email
- address
- notes
- preferred_contact_channel
- is_active
- created_at
- updated_at

### customer_balances
- id
- business_id
- customer_id
- outstanding_amount
- last_payment_at
- updated_at

### products
- id
- business_id
- name
- sku
- category
- unit
- cost_price
- selling_price
- reorder_level
- is_active
- created_at
- updated_at

### stock_items
- id
- business_id
- product_id
- quantity_on_hand
- quantity_reserved
- last_counted_at
- updated_at

### inventory_movements
- id
- business_id
- product_id
- user_id
- movement_type
- quantity
- reason
- source_type
- source_id
- notes
- created_at

movement_type examples:
- stock_in
- sale_out
- return_in
- damage_out
- adjustment_up
- adjustment_down

### sales
- id
- business_id
- customer_id nullable
- cashier_id
- subtotal_amount
- discount_amount
- tax_amount
- total_amount
- payment_status
- sale_status
- notes
- created_at
- updated_at

### sale_items
- id
- sale_id
- product_id
- quantity
- unit_price
- line_total
- created_at

### invoices
- id
- business_id
- customer_id
- sale_id nullable
- invoice_number
- amount_due
- amount_paid
- balance_remaining
- due_date
- status
- payment_link
- provider_name
- provider_reference
- created_by
- created_at
- updated_at

status examples:
- draft
- sent
- partially_paid
- paid
- overdue
- cancelled

### payments
- id
- business_id
- customer_id nullable
- invoice_id nullable
- sale_id nullable
- provider_name
- provider_reference
- internal_reference
- amount
- currency
- payment_channel
- status
- paid_at nullable
- raw_response_json
- created_at
- updated_at

status examples:
- initialized
- pending
- succeeded
- failed
- cancelled

### payment_provider_connections
- id
- business_id
- provider_name
- account_label
- public_reference
- encrypted_secret_payload
- status
- connected_at
- updated_at

### notifications
- id
- business_id
- customer_id nullable
- channel
- template_name
- message_body
- status
- external_reference
- related_type
- related_id
- sent_at
- created_at

### audit_logs
- id
- business_id
- user_id nullable
- action
- entity_type
- entity_id
- old_values_json
- new_values_json
- ip_address
- user_agent
- created_at

## Relationships
- business has many users
- business has many customers
- business has many products
- business has many sales
- business has many invoices
- business has many payments
- product has one stock record and many inventory movements
- sale has many sale items
- invoice can link to one sale
- payment can link to invoice and/or sale
- customer can have many invoices and many payments

## Important Indexes
- business_id on all tenant tables
- customers(phone, business_id)
- products(sku, business_id)
- invoices(provider_reference)
- payments(provider_reference)
- notifications(status, channel)
- inventory_movements(product_id, created_at)
- audit_logs(entity_type, entity_id)

## Data Integrity Rules
- no payment success without a provider_reference
- no inventory reduction without inventory movement record
- no invoice marked paid unless payment verification succeeds
- all tenant queries filtered by business_id
- every important mutation writes audit log
