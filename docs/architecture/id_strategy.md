# Identifier strategy

- **Primary keys:** UUID v4 (PostgreSQL `UUID` type) on all public tables for stable references across devices and sync.
- **Idempotent sync:** Offline-created rows include `source_device_id` + `local_operation_id` (see `architecture.md` §8). The pair must be unique per logical operation; `sync_operations` enforces uniqueness for applied server-side records.

Document changes here if you introduce bigint sequences for internal-only tables.
