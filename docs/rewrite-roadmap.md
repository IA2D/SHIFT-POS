# Rewrite Roadmap

This is the execution plan for rebuilding SHIFT POS as a clean Android and Windows product.

## Phase 0: Foundation

Status: in progress.

Goals:

- Real Flutter project.
- Android and Windows targets.
- Clean folder boundaries.
- Runtime config.
- Database linkage disabled.
- API endpoint configurable.
- No Firebase.
- Testable domain code.

Acceptance:

- `flutter analyze` passes.
- `flutter test` passes.
- App shell runs without database or API.

## Phase 1: Local Domain Core

Goals:

- Define stable entities and value objects.
- Keep calculations outside widgets.
- Keep repositories behind interfaces.
- Use transactions for mutable financial and inventory state.

Modules:

- Orders.
- Payments.
- Shifts.
- Inventory transactions.
- Supplier transactions.
- Users and permissions.
- Settings.
- Printers.
- Audit events.

Acceptance:

- Order totals are deterministic and tested.
- Inventory balances are derived from transactions.
- Supplier debt is derived from transactions.
- Audit events use usernames and structured metadata.

## Phase 2: SQLite Persistence

Goals:

- Add SQLite only after schemas are reviewed.
- Add migrations from day one.
- Keep database implementation behind repository interfaces.

Rules:

- No widget imports database packages.
- No raw table sync from UI.
- No hidden database writes outside services.

Acceptance:

- Schema version table exists.
- Migrations are tested.
- Repository tests can run against temporary databases.

## Phase 3: Authentication and Permissions

Goals:

- Local auth for standalone/master.
- Master-owned auth for side devices.
- Role and permission enforcement in UI and services.

Acceptance:

- Login does not prefill credentials.
- Username is used in audit logs.
- Unauthorized routes/actions are hidden and blocked.

## Phase 4: POS MVP

Goals:

- Menu browsing.
- Cart.
- Takeaway.
- Delivery.
- Dine-in.
- Add items to occupied table order.
- Cash/card/split payments.
- Current-shift history.

Acceptance:

- Orders persist locally.
- Dine-in orders stay unpaid until checkout.
- Customer receipt prints only at payment.
- Kitchen tickets print at order save/update.

## Phase 5: Manager MVP

Goals:

- Dashboard.
- Accounts.
- Items and categories.
- Inventory.
- Purchases.
- Suppliers.
- Shifts.
- Reports.
- Audit log.
- Settings.

Acceptance:

- Permissions gate every tab and action.
- Manager operations create detailed audit entries.
- Supplier debts and inventory movements are transaction based.

## Phase 6: Printing

Goals:

- Receipt document model.
- ESC/POS renderer.
- Kitchen batching.
- Device default printers.
- Windows printing.
- Android network/Bluetooth/USB printing.

Acceptance:

- Preview matches output as closely as possible.
- Missing printer config shows clear warnings.
- Print failure does not roll back saved orders.

## Phase 7: Master/Side LAN

Goals:

- Any Windows or Android device can be standalone/master.
- Side devices connect to master through LAN.
- Side devices do not create POS databases.

Acceptance:

- Pairing tokens are required.
- Revoked tokens fail immediately.
- Side login is validated by master.
- Side writes go through master API.

## Phase 8: API Sync

Goals:

- App talks only to a backend API.
- Backend database choice is hidden behind the API.
- API can be load-balanced.

Rules:

- Sync business entities/events, not raw SQLite tables.
- Use outbox and idempotency keys.
- Use versioning/conflict rules.

Acceptance:

- App can work offline and sync later.
- API base URL is config-driven.
- Database type can change behind the API.

## Phase 9: Backend

Goals:

- Stateless API.
- Tenant/store isolation.
- Device tokens.
- Sync pull/push endpoints.
- Database repository abstraction.

Acceptance:

- Works behind a load balancer.
- Logs include request IDs.
- PostgreSQL can be the first backend without locking the app to it.

## Phase 10: Production Readiness

Goals:

- Full test coverage around critical business logic.
- Android and Windows release builds.
- Backup and restore.
- Migration/import tooling when needed.
- Operator documentation.

Acceptance:

- Cashier flows are tested.
- Manager flows are tested.
- Printing is tested against real printers.
- LAN mode is tested across Android and Windows devices.
