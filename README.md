# SHIFT POS

Clean cross-platform rewrite of SHIFT POS for Windows and Android.

The app is designed to run in three modes:

- Standalone: local device owns its SQLite database.
- Master: local device owns SQLite and exposes a LAN API.
- Side: device connects to a master and does not create a POS database.

Firebase is intentionally excluded. Future online sync must go through a backend API. The backend can use PostgreSQL, MySQL, SQL Server, or another database behind its own service layer without changing the app.

## Current Rewrite Status

This repository is at the foundation stage.

Implemented now:

- Real Flutter project with Android and Windows platform folders.
- Clean feature/core/shared folder structure.
- Runtime config file.
- Database linkage disabled by config.
- API endpoint configurable by config.
- Platform/database/sync interfaces prepared.
- In-memory auth/session flow with no prefilled login credentials.
- Permission-aware shell navigation.
- In-memory POS settings repository for restaurant name, currency, tax, service, and delivery fee.
- Tested order pricing service.
- Tested inventory transaction balance service.
- Tested supplier debt balance service.
- Usable in-memory POS MVP:
  - seeded menu
  - cart
  - takeaway/dine-in/delivery modes
  - table selection for dine-in
  - cash/card selection for paid orders
  - order totals preview
  - in-memory order saving
  - unpaid dine-in order list
  - dine-in checkout by cash or card
- Manager dashboard reads live in-memory orders and shows:
  - total orders
  - paid orders
  - unpaid dine-in orders
  - paid sales total
  - recent orders
- Minimal RTL app shell for POS, Manager, and Settings.

Not implemented yet:

- SQLite connection.
- Backend API calls.
- Printing.
- Full production POS workflows.
- Master/side LAN server.

## Configuration

Runtime config lives in:

```text
assets/config/app_config.json
```

Initial config:

```json
{
  "environment": "development",
  "api": {
    "enabled": false,
    "baseUrl": "http://127.0.0.1:8080",
    "timeoutSeconds": 20
  },
  "database": {
    "enabled": false,
    "driver": "sqlite",
    "name": "shift_pos.sqlite"
  },
  "network": {
    "defaultMasterPort": 47831
  }
}
```

For the first versions, `database.enabled` should remain `false`. This lets the app shell and domain structure grow without hiding accidental database coupling inside UI code.

## Architecture

```text
lib/
  app/
    App widget, routing, shell composition
  core/
    config, database, networking, platform service contracts
  features/
    auth, pos, manager, settings
  shared/
    theme, widgets, value objects
```

Rules:

- UI screens must not talk directly to SQLite, files, printers, or HTTP.
- Features depend on interfaces, not platform implementations.
- Business logic belongs in domain/application services, not widgets.
- Sync uses business entities/events, not raw table mirroring.
- Platform-specific code goes behind adapters.

## First Milestones

1. Build the local domain model.
2. Add local repositories behind interfaces.
3. Add SQLite only after schemas and migrations are reviewed.
4. Rebuild authentication and permissions.
5. Rebuild POS order flow.
6. Add receipt document model.
7. Add master/side LAN API.
8. Add backend sync API client.

See the full implementation roadmap in:

```text
docs/rewrite-roadmap.md
```

## Development

Flutter is required to build this project.

```powershell
flutter pub get
flutter run -d windows
flutter run -d android
```

The current machine used to create this skeleton did not have Flutter/Dart installed, so the first validation step after installing Flutter is:

```powershell
flutter analyze
flutter test
```

Current verification:

- `flutter analyze` passes.
- `flutter test` passes.
- `flutter build windows` passes.
- Android release APK was built at `build/app/outputs/flutter-apk/app-release.apk`.
- Windows release executable was built at `build/windows/x64/runner/Release/shift_pos.exe`.
