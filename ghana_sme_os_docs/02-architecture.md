# Architecture

## High-Level Architecture
The system is a multi-tenant business platform where each merchant has:
- their own business account
- their own staff users
- their own inventory
- their own customers
- their own invoices and sales
- their own merchant-owned Paystack account for payment processing

## Core Components
1. Client applications
2. Backend API
3. Database
4. Background job system
5. Notification services
6. Payment integration layer
7. Audit and reporting layer

## Suggested Stack

### Frontend
- Flutter mobile app for Android-first merchant experience
- Optional web dashboard later for admin/reporting

### Backend
- FastAPI

### Database
- PostgreSQL

### Async / Background Jobs
- Redis
- Celery or equivalent job queue

### Notifications
- WhatsApp Business Platform
- SMS provider fallback

### Payments
- Paystack as version 1 payment provider

### Hosting
- Backend: Render, Railway, Fly.io, AWS, or similar
- Database: Managed PostgreSQL
- Redis: Managed Redis

## Multi-Tenant Model
Every record must belong to a business.
Examples:
- users belong to a business
- customers belong to a business
- products belong to a business
- invoices belong to a business
- payments belong to a business

This allows one application instance to serve many merchants while keeping data isolated.

## Major Services

### 1. Auth Service
Responsible for:
- login
- token issuance
- session handling
- password reset
- role enforcement

### 2. Business Service
Responsible for:
- business profile
- settings
- payment connection state
- plan/billing state in future

### 3. Product & Inventory Service
Responsible for:
- products
- stock levels
- stock adjustments
- reorder thresholds
- inventory movement logs

### 4. Sales Service
Responsible for:
- sales
- sale items
- returns
- cashier activity
- payment state linkage

### 5. Customer & Debt Service
Responsible for:
- customer profiles
- credit sales
- invoices
- outstanding balances
- payment reminders

### 6. Payment Service
Responsible for:
- invoice-linked payment requests
- Paystack integration
- transaction reference tracking
- webhook handling
- payment verification
- payout state visibility if needed

### 7. Notification Service
Responsible for:
- WhatsApp receipts
- SMS fallback
- payment reminders
- daily owner summaries
- low stock alerts

### 8. Reporting Service
Responsible for:
- daily sales summaries
- debt summaries
- low stock lists
- staff activity summaries
- simple profit estimation

### 9. Audit Service
Responsible for:
- user actions
- inventory edits
- sale cancellations
- invoice status changes
- payment status changes

## Event-Driven Updates
The architecture should be designed so important system actions produce events.

Example events:
- sale.created
- sale.completed
- invoice.created
- reminder.sent
- payment.pending
- payment.succeeded
- payment.failed
- stock.low
- stock.adjusted
- worker.role.changed

These events can trigger:
- inventory updates
- customer notifications
- reports
- audit logs
- analytics

## Security Requirements
- JWT-based auth or secure session auth
- hashed passwords
- encrypted secrets at rest
- webhook signature validation
- tenant isolation at query layer
- role-based authorization
- audit trail for critical actions

## Architecture Rule For Payments
The application must never behave like it is holding merchant money.
The payment provider processes and settles the money.
The application tracks references, statuses, and business logic only.
