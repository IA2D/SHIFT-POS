# Manager Migration Tasks

Source of truth: the Electron manager routes under `src/renderer/src/features/manager`.

## 1. Dashboard
- Match summary cards: today orders, today revenue, week revenue.
- Add manager quick tiles for every permitted management section.
- Add restart/update controls where platform support exists.

## 2. Items
- Migrate item list and category management.
- Migrate sizes, addons, raw materials tabs.
- Migrate item create/edit, weighted products, recipes, kitchen printer assignment.
- Add reorder support for categories/items/sizes/addons.

## 3. Tables
- Migrate floor plan areas, tables, chairs, walls, drag/resize, and canvas zoom.
- Add POS visual table selector parity.

## 4. Purchases And Inventory
- Migrate purchase entry, waste, adjustments, and inventory ledger.
- Add ingredient stock balance reporting.
- Connect purchases to suppliers and supplier balances.

## 5. Accounts
- Migrate users, roles, permissions, PIN lock settings, and cashier limits.
- Add audit events for account changes.

## 6. Shifts
- Migrate open/close shift, cash drawer opening/closing amounts, unpaid warnings.
- Add shift archive and cashier settlement reports.

## 7. Suppliers
- Migrate supplier CRUD, purchase history, payment/debt ledger.
- Add balance calculation parity with Electron.

## 8. Cashier History
- Migrate cashier daily order history, filters, cancellations, and reprint controls.

## 9. Reports
- Migrate sales, revenue, inventory, supplier, cashier, and date-range reports.
- Add export/print equivalents where supported.

## 10. Audit
- Migrate audit log storage, filters, event details, and security-sensitive events.

## 11. Settings
- Migrate restaurant profile, tax/service/delivery, printer settings, backup, networking, keyboard shortcuts, theme, and master/side mode.

## Current Flutter Status
- Full manager navigation surface exists in `lib/features/manager/presentation/manager_page.dart`.
- Dashboard, menu, purchases/inventory, accounts, shifts, suppliers, reports,
  cashier history, and audit now read and write through repository interfaces.
- Purchases includes stock/ingredient tabs, low-stock alerts, supplier debt,
  waste, adjustments, and ingredient CRUD.
- Accounts includes role presets, granular permissions, active state, password,
  PIN, and deletion controls.
- Shifts includes active/archive views and a sales/cash reconciliation summary.
- Reports includes date ranges plus daily, item, and cashier views.
- Cashier history includes filters, receipt detail, cancellation, and audit.
- Audit includes text/action filters and event detail inspection.
- SQLite schema v6 now persists accounts, hashed credentials, ingredients,
  inventory movements, suppliers, supplier ledger entries, shifts, and audit
  events on Windows and Android, plus categories, items, sizes, addons, nested
  item options, and recipes.
- Orders, order numbering, dining tables, and core POS settings now use the
  same durable database in production.
- Item management supports create/edit/delete, active state, ordering,
  category hierarchy, size pricing, addons, weighted prices, custom weight,
  linked stock, raw materials, and recipe composition.
- SQLite schema v4 persists floor areas, table geometry, shapes, rotation,
  independent chair positions, and wall segments.
- Manager floor-plan editing now includes floor tabs, grid/zoom controls,
  table add/edit/delete, drag/resize, shape/rotation, chair movement and
  reassignment, plus wall drawing/movement. POS uses the same visual map with
  occupied, available, and selected table states.
- SQLite schema v5 persists signed cash-drawer movements. Login guarantees an
  open cashier shift, cash sales are recorded against orders, and manager shift
  closing includes expected/actual cash, differences, unpaid-order warnings,
  manual drawer movements, item totals, and inventory movement details.
- SQLite schema v6 persists kitchen printer definitions and item-to-printer
  routing. Manager settings can discover Windows printers and configure ticket
  copies and visibility per order type.
- Manager settings now has general, theme, PIN/lock, receipt designer, network,
  backup/restore, and keyboard shortcut tabs. All settings persist across
  restarts; theme changes apply live, inactivity lock is enforced, and POS and
  shell shortcuts dispatch to their configured actions.
- Database backup/restore is implemented at the SQLite gateway and covered by
  round-trip tests, alongside expanded settings restart coverage.

## Remaining Parity Work
- Complete Items parity for image attachments.
- Complete floor-plan parity for marquee multi-selection and keyboard delete.
- Add shift-summary receipt printing through the platform print adapter.
- Add report CSV/PDF export and Windows/Android print adapters.
- Complete settings receipt preview/logo file picking, scheduled multi-folder
  backup retention, network master/side transport, update, and restart behavior.
- Add production barcode scanning, receipt/kitchen printing, and Android
  hardware adapters.
