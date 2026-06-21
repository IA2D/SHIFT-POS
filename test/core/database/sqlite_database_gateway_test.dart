import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shift_pos/core/database/sqlite_database_gateway.dart';
import 'package:shift_pos/core/database/database_tables.dart';
import 'package:shift_pos/features/audit/data/sqlite_audit_repository.dart';
import 'package:shift_pos/features/audit/domain/audit_event.dart';
import 'package:shift_pos/features/auth/data/sqlite_auth_repository.dart';
import 'package:shift_pos/features/auth/domain/app_user.dart';
import 'package:shift_pos/features/cash/data/sqlite_cash_repository.dart';
import 'package:shift_pos/features/cash/domain/cash_drawer_transaction.dart';
import 'package:shift_pos/features/inventory/data/sqlite_inventory_repository.dart';
import 'package:shift_pos/features/inventory/domain/ingredient.dart';
import 'package:shift_pos/features/menu/data/sqlite_menu_repository.dart';
import 'package:shift_pos/features/menu/domain/menu_item.dart';
import 'package:shift_pos/features/orders/data/sqlite_order_repository.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_line.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';
import 'package:shift_pos/features/printers/data/sqlite_printer_repository.dart';
import 'package:shift_pos/features/printers/domain/kitchen_printer.dart';
import 'package:shift_pos/features/settings/data/sqlite_settings_repository.dart';
import 'package:shift_pos/features/settings/domain/pos_settings.dart';
import 'package:shift_pos/features/shifts/data/sqlite_shift_repository.dart';
import 'package:shift_pos/features/suppliers/data/sqlite_supplier_repository.dart';
import 'package:shift_pos/features/suppliers/domain/supplier.dart';
import 'package:shift_pos/features/tables/data/sqlite_table_repository.dart';
import 'package:shift_pos/features/tables/domain/dining_table.dart';
import 'package:shift_pos/features/tables/domain/floor_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('shift_pos_db_');
    databasePath = path.join(temporaryDirectory.path, 'test.sqlite');
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('manager repositories survive database restart without reseeding',
      () async {
    final firstGateway = SqliteDatabaseGateway(
      fileName: 'test.sqlite',
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await firstGateway.initialize();

    final firstAuth = SqliteAuthRepository(firstGateway);
    final firstInventory = SqliteInventoryRepository(firstGateway);
    final firstMenu = SqliteMenuRepository(firstGateway);
    final firstOrders = SqliteOrderRepository(firstGateway);
    final firstTables = SqliteTableRepository(firstGateway);
    final firstSettings = SqliteSettingsRepository(firstGateway);
    final firstCash = SqliteCashRepository(firstGateway);
    final firstPrinters = SqlitePrinterRepository(firstGateway);
    final firstSuppliers = SqliteSupplierRepository(firstGateway);
    final firstShifts = SqliteShiftRepository(firstGateway);
    final firstAudit = SqliteAuditRepository(firstGateway);
    await firstAuth.initialize();
    await firstInventory.initialize();
    await firstMenu.initialize();
    await firstOrders.initialize();
    await firstTables.initialize();
    await firstSettings.initialize();
    await firstSuppliers.initialize();
    await firstShifts.initialize();
    await firstAudit.initialize();

    await firstAuth.saveAccount(
      const AppUser(
        id: 'cashier-1',
        username: 'cashier',
        displayName: 'Cashier One',
        role: UserRole.cashier,
        permissions: {Permission.accessPos},
      ),
      password: 'secret1',
    );
    await firstAuth.setPin('cashier-1', '2468');
    await firstInventory.saveIngredient(
      const Ingredient(id: 'rice', nameAr: 'Rice', unit: 'kg'),
    );
    await firstSuppliers.saveSupplier(
      const Supplier(id: 'supplier-rice', nameAr: 'Rice Supplier'),
    );
    final originalItem = (await firstMenu.listItems()).first;
    await firstMenu.saveItem(originalItem.copyWith(nameAr: 'Persisted item'));
    await firstOrders.save(
      Order(
        id: 'order-persisted',
        orderNumber: await firstOrders.nextOrderNumber(),
        type: OrderType.takeaway,
        lines: const [
          OrderLine(
            menuItemId: 'rice',
            nameAr: 'Rice',
            unitPrice: 20,
            quantity: 2,
          ),
        ],
        totals: const OrderTotals(
          subtotal: 40,
          discountAmount: 0,
          taxAmount: 0,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 40,
        ),
        status: OrderStatus.unpaid,
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await firstTables.saveTable(
      const DiningTable(
        id: 'roof-1',
        nameAr: 'Roof 1',
        sectionAr: 'Roof',
        floorId: 'floor-roof',
        x: 220,
        y: 180,
        width: 120,
        height: 80,
        rotation: 90,
        chairPositions: [
          TableChairPosition(id: 'roof-chair-1', x: 210, y: 160),
        ],
        sortOrder: 50,
      ),
    );
    await firstTables.saveFloor(
      const FloorPlanArea(
        id: 'floor-roof',
        nameAr: 'Roof',
        width: 900,
        height: 600,
        walls: [
          FloorWall(id: 'roof-wall', x1: 0, y1: 0, x2: 900, y2: 0),
        ],
      ),
    );
    await firstSettings.savePosSettings(
      PosSettings(
        restaurantNameAr: 'Persistent Restaurant',
        currencySymbol: 'EGP',
        taxRate: 12,
        serviceRate: 5,
        deliveryFee: 30,
        phoneNumber: '01000000000',
        receiptFooterAr: 'Thanks',
        primaryColor: '#15803D',
        pinEnabled: true,
        autoLockMinutes: 9,
        maxCashierDiscountPct: 15,
        keyboardShortcuts: const {'checkoutCash': 'f8'},
        networkMode: NetworkMode.master,
        masterServerPort: 49000,
        receiptPrintRoute: ReceiptPrintRoute.master,
        receiptSectionOrder: const [
          ReceiptSection.restaurant,
          ReceiptSection.items,
          ReceiptSection.totals,
          ReceiptSection.footer,
        ],
        receiptHiddenSections: const {ReceiptSection.footer},
        receiptShowItemNotes: false,
        receiptCompactMode: true,
        receiptLogoEnabled: true,
        receiptLogoDataUrl: 'data:image/png;base64,AA==',
        receiptLogoMode: ReceiptLogoMode.monochrome,
        receiptLogoThreshold: 190,
        receiptLogoWidth: 120,
        receiptLogoInvert: true,
        receiptLogoAlign: ReceiptLogoAlign.right,
        receiptLogoMaxWidthPercent: 80,
        backupDirectory: 'D:/backups',
        backupDirectories: const ['E:/backup-one', 'F:/backup-two'],
        autoBackupEnabled: true,
        autoBackupIntervalDays: 2,
        autoBackupOnClose: true,
        backupRetentionDays: 30,
        lastAutoBackupAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await firstCash.saveTransaction(
      CashDrawerTransaction(
        id: 'cash-persisted',
        type: CashDrawerTransactionType.expense,
        amount: -25,
        shiftId: 'shift-admin-open',
        noteAr: 'Expense',
        createdBy: 'admin',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await firstPrinters.saveKitchenPrinter(
      const KitchenPrinter(
        id: 'kitchen-grill',
        name: 'Grill',
        deviceName: 'Printer 1',
        copies: 2,
        visibility: KitchenPrinterVisibility(showCustomer: false),
      ),
    );
    await firstAudit.record(
      AuditEvent(
        id: 'audit-persisted',
        action: 'test',
        actorUsername: 'admin',
        createdAt: DateTime.utc(2026, 1, 2),
        metadata: const {'persisted': true},
      ),
    );
    expect((await firstShifts.listShifts()), isNotEmpty);
    await firstGateway.close();

    final secondGateway = SqliteDatabaseGateway(
      fileName: 'test.sqlite',
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await secondGateway.initialize();
    final secondAuth = SqliteAuthRepository(secondGateway);
    final secondInventory = SqliteInventoryRepository(secondGateway);
    final secondMenu = SqliteMenuRepository(secondGateway);
    final secondOrders = SqliteOrderRepository(secondGateway);
    final secondTables = SqliteTableRepository(secondGateway);
    final secondSettings = SqliteSettingsRepository(secondGateway);
    final secondCash = SqliteCashRepository(secondGateway);
    final secondPrinters = SqlitePrinterRepository(secondGateway);
    final secondSuppliers = SqliteSupplierRepository(secondGateway);
    final secondShifts = SqliteShiftRepository(secondGateway);
    final secondAudit = SqliteAuditRepository(secondGateway);
    await secondAuth.initialize();
    await secondInventory.initialize();
    await secondMenu.initialize();
    await secondOrders.initialize();
    await secondTables.initialize();
    await secondSettings.initialize();
    await secondSuppliers.initialize();
    await secondShifts.initialize();
    await secondAudit.initialize();

    expect(
      await secondAuth.login(username: 'cashier', password: 'secret1'),
      isNotNull,
    );
    expect(await secondAuth.verifyPin('cashier-1', '2468'), isTrue);
    expect(await secondAuth.verifyPin('cashier-1', '0000'), isFalse);
    expect(
      (await secondInventory.listIngredients())
          .where((ingredient) => ingredient.id == 'rice'),
      hasLength(1),
    );
    expect(
      (await secondSuppliers.listSuppliers())
          .where((supplier) => supplier.id == 'supplier-rice'),
      hasLength(1),
    );
    expect(
      (await secondMenu.listItems(includeInactive: true))
          .where((item) => item.nameAr == 'Persisted item'),
      hasLength(1),
    );
    expect(await secondOrders.getById('order-persisted'), isNotNull);
    expect(await secondOrders.nextOrderNumber(), 2);
    expect(
      (await secondTables.listTables()).where((table) => table.id == 'roof-1'),
      hasLength(1),
    );
    final persistedTable = (await secondTables.listTables())
        .singleWhere((table) => table.id == 'roof-1');
    expect(persistedTable.rotation, 90);
    expect(persistedTable.chairPositions.single.id, 'roof-chair-1');
    final persistedFloor = (await secondTables.listFloors())
        .singleWhere((floor) => floor.id == 'floor-roof');
    expect(persistedFloor.walls.single.id, 'roof-wall');
    final persistedSettings = await secondSettings.getPosSettings();
    expect(persistedSettings.restaurantNameAr, 'Persistent Restaurant');
    expect(persistedSettings.phoneNumber, '01000000000');
    expect(persistedSettings.primaryColor, '#15803D');
    expect(persistedSettings.pinEnabled, isTrue);
    expect(persistedSettings.autoLockMinutes, 9);
    expect(persistedSettings.keyboardShortcuts['checkoutCash'], 'f8');
    expect(persistedSettings.networkMode, NetworkMode.master);
    expect(persistedSettings.masterServerPort, 49000);
    expect(persistedSettings.receiptPrintRoute, ReceiptPrintRoute.master);
    expect(
        persistedSettings.receiptSectionOrder.first, ReceiptSection.restaurant);
    expect(persistedSettings.receiptHiddenSections,
        contains(ReceiptSection.footer));
    expect(persistedSettings.receiptCompactMode, isTrue);
    expect(persistedSettings.receiptLogoMode, ReceiptLogoMode.monochrome);
    expect(persistedSettings.backupDirectories, hasLength(2));
    expect(persistedSettings.autoBackupOnClose, isTrue);
    expect(persistedSettings.backupRetentionDays, 30);
    expect(
      (await secondCash.listTransactions())
          .singleWhere((transaction) => transaction.id == 'cash-persisted')
          .amount,
      -25,
    );
    final persistedPrinter =
        (await secondPrinters.listKitchenPrinters()).single;
    expect(persistedPrinter.copies, 2);
    expect(persistedPrinter.visibility.showCustomer, isFalse);
    expect((await secondShifts.listShifts()), hasLength(1));
    expect(
      (await secondAudit.listEvents())
          .where((event) => event.id == 'audit-persisted'),
      hasLength(1),
    );
    await secondGateway.close();
  });

  test('rejects unknown table names', () async {
    final gateway = SqliteDatabaseGateway(
      fileName: 'test.sqlite',
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await gateway.initialize();
    expect(() => gateway.query('not_a_table'), throwsArgumentError);
    await gateway.close();
  });

  test('creates and restores a complete database backup', () async {
    final gateway = SqliteDatabaseGateway(
      fileName: 'test.sqlite',
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await gateway.initialize();
    await gateway.save(
      DatabaseTables.settings,
      'backup-probe',
      const {'value': 'before'},
    );

    final backupPath = await gateway.createBackup(
      directoryPath: temporaryDirectory.path,
    );
    expect(File(backupPath).existsSync(), isTrue);

    await gateway.save(
      DatabaseTables.settings,
      'backup-probe',
      const {'value': 'after'},
    );
    await gateway.restoreBackup(backupPath);

    final restored = await gateway.query(
      DatabaseTables.settings,
      filters: const {'id': 'backup-probe'},
    );
    expect(restored.single['value'], 'before');
    await gateway.close();
  });

  test('upgrades schema version 1 databases through the latest schema',
      () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) async {
          for (final table in DatabaseTables.managerV1) {
            await database.execute('''
              CREATE TABLE $table (
                id TEXT PRIMARY KEY NOT NULL,
                payload TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          }
        },
      ),
    );
    await legacy.close();

    final gateway = SqliteDatabaseGateway(
      fileName: 'test.sqlite',
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    await gateway.initialize();
    expect(await gateway.query(DatabaseTables.menuItems), isEmpty);
    expect(await gateway.query(DatabaseTables.recipes), isEmpty);
    expect(await gateway.query(DatabaseTables.orders), isEmpty);
    expect(await gateway.query(DatabaseTables.floors), isEmpty);
    expect(
      await gateway.query(DatabaseTables.cashDrawerTransactions),
      isEmpty,
    );
    expect(await gateway.query(DatabaseTables.kitchenPrinters), isEmpty);
    await gateway.close();
  });
}
