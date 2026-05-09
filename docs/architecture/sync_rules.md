# Sync & Connectivity Rules

This document outlines the deterministic rules for synchronization and backend reachability in SikaBoafo.

## 1. Reachability Detection (Offline Pill)
The system does not rely on OS-level network status (which can be misleading). It performs an active health check.

- **Endpoint**: `GET /health`
- **Success Criteria**: Response body `{"status": "ok"}`.
- **Debounce Logic**: To prevent "Offline" flicker during transient blips (Wi-Fi handoff), the UI only transitions to Offline after **2 consecutive failed pings** (~40s).
- **Caching**: The last confirmed status is cached in `_lastKnownReachable`. On app launch or tab switch, the system defaults to this last known state instead of assuming "Offline" while the first ping is in flight.

## 2. Sync Queue Lifecycle
All writes (Sales, Expenses, Inventory adjustments) are recorded locally in SQLite first.

1. **Pending**: Entry created in `sync_queue`.
2. **Sending**: In-flight to the backend.
3. **Applied**: Successfully processed by backend (idempotent unique constraint `source_device_id` + `local_operation_id` prevents duplicates).
4. **Conflict**: Backend rejected the write due to a state mismatch (e.g., trying to archive an item that still has stock on the server).
5. **Dead-Letter**: Moved to dead-letter after 10 failed attempts to prevent infinite retries.

## 3. Conflict Resolution
- **Archive/Delete**: If a device tries to archive an item but the server has a newer version or pending stock, the server returns a `conflict`. 
- **Auto-Refresh**: Conflicts trigger a background pull of the latest server state (`SyncRefreshService`) to reconcile the local database.

## 4. Notifications
- **Offline Alerts**: Fired only after the 2-ping debounce confirms a sustained outage.
- **Success Alerts**: Fired for all successful checkouts (Cash, Card, MoMo) to provide immediate merchant feedback.
- **Low Stock**: Checked once per day when the inventory tab is accessed or after a sync event.
