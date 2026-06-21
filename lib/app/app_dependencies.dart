import 'package:flutter/foundation.dart';

import 'app_command_bus.dart';
import '../features/audit/data/in_memory_audit_repository.dart';
import '../features/audit/data/sqlite_audit_repository.dart';
import '../features/audit/domain/audit_repository.dart';
import '../features/auth/data/in_memory_auth_repository.dart';
import '../features/auth/data/sqlite_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/cash/data/in_memory_cash_repository.dart';
import '../features/cash/data/sqlite_cash_repository.dart';
import '../features/cash/domain/cash_repository.dart';
import '../core/config/app_config.dart';
import '../core/database/database_gateway.dart';
import '../core/database/sqlite_database_gateway.dart';
import '../features/inventory/data/in_memory_inventory_repository.dart';
import '../features/inventory/data/sqlite_inventory_repository.dart';
import '../features/inventory/domain/inventory_repository.dart';
import '../features/menu/data/in_memory_menu_repository.dart';
import '../features/menu/data/sqlite_menu_repository.dart';
import '../features/menu/domain/menu_repository.dart';
import '../features/orders/data/in_memory_order_repository.dart';
import '../features/orders/data/sqlite_order_repository.dart';
import '../features/orders/domain/order_repository.dart';
import '../features/printers/data/in_memory_printer_repository.dart';
import '../features/printers/data/sqlite_printer_repository.dart';
import '../features/printers/domain/printer_repository.dart';
import '../features/settings/data/in_memory_settings_repository.dart';
import '../features/settings/data/sqlite_settings_repository.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/settings/domain/pos_settings.dart';
import '../features/shifts/data/in_memory_shift_repository.dart';
import '../features/shifts/data/sqlite_shift_repository.dart';
import '../features/shifts/domain/shift_repository.dart';
import '../features/suppliers/data/in_memory_supplier_repository.dart';
import '../features/suppliers/data/sqlite_supplier_repository.dart';
import '../features/suppliers/domain/supplier_repository.dart';
import '../features/tables/data/in_memory_table_repository.dart';
import '../features/tables/data/sqlite_table_repository.dart';
import '../features/tables/domain/table_repository.dart';

class AppDependencies {
  AppDependencies({
    MenuRepository? menuRepository,
    TableRepository? tableRepository,
    OrderRepository? orderRepository,
    AuthRepository? authRepository,
    SettingsRepository? settingsRepository,
    InventoryRepository? inventoryRepository,
    SupplierRepository? supplierRepository,
    ShiftRepository? shiftRepository,
    AuditRepository? auditRepository,
    CashRepository? cashRepository,
    PrinterRepository? printerRepository,
    ValueNotifier<PosSettings>? settingsNotifier,
    AppCommandBus? commandBus,
    this.databaseGateway,
  })  : menuRepository = menuRepository ?? InMemoryMenuRepository.seeded(),
        tableRepository = tableRepository ?? InMemoryTableRepository.seeded(),
        orderRepository = orderRepository ?? InMemoryOrderRepository(),
        authRepository = authRepository ?? InMemoryAuthRepository(),
        settingsRepository = settingsRepository ?? InMemorySettingsRepository(),
        inventoryRepository =
            inventoryRepository ?? InMemoryInventoryRepository.seeded(),
        supplierRepository =
            supplierRepository ?? InMemorySupplierRepository.seeded(),
        shiftRepository = shiftRepository ?? InMemoryShiftRepository.seeded(),
        auditRepository = auditRepository ?? InMemoryAuditRepository.seeded(),
        cashRepository = cashRepository ?? InMemoryCashRepository(),
        printerRepository = printerRepository ?? InMemoryPrinterRepository(),
        settingsNotifier = settingsNotifier ??
            ValueNotifier(
              const PosSettings(
                restaurantNameAr: 'SHIFT POS',
                currencySymbol: 'EGP',
                taxRate: 14,
                serviceRate: 0,
                deliveryFee: 25,
              ),
            ),
        commandBus = commandBus ?? AppCommandBus();

  static Future<AppDependencies> create(AppConfig config) async {
    if (!config.database.enabled) return AppDependencies();
    if (config.database.driver.toLowerCase() != 'sqlite') {
      throw UnsupportedError(
        'Unsupported database driver: ${config.database.driver}',
      );
    }

    final database = SqliteDatabaseGateway(fileName: config.database.name);
    await database.initialize();

    final auth = SqliteAuthRepository(database);
    final menu = SqliteMenuRepository(database);
    final orders = SqliteOrderRepository(database);
    final tables = SqliteTableRepository(database);
    final settings = SqliteSettingsRepository(database);
    final inventory = SqliteInventoryRepository(database);
    final suppliers = SqliteSupplierRepository(database);
    final shifts = SqliteShiftRepository(database);
    final audit = SqliteAuditRepository(database);
    final cash = SqliteCashRepository(database);
    final printers = SqlitePrinterRepository(database);
    await auth.initialize();
    await menu.initialize();
    await orders.initialize();
    await tables.initialize();
    await settings.initialize();
    await inventory.initialize();
    await suppliers.initialize();
    await shifts.initialize();
    await audit.initialize();
    final currentSettings = await settings.getPosSettings();

    return AppDependencies(
      authRepository: auth,
      menuRepository: menu,
      orderRepository: orders,
      tableRepository: tables,
      settingsRepository: settings,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      shiftRepository: shifts,
      auditRepository: audit,
      cashRepository: cash,
      printerRepository: printers,
      settingsNotifier: ValueNotifier(currentSettings),
      databaseGateway: database,
    );
  }

  final MenuRepository menuRepository;
  final TableRepository tableRepository;
  final OrderRepository orderRepository;
  final AuthRepository authRepository;
  final SettingsRepository settingsRepository;
  final InventoryRepository inventoryRepository;
  final SupplierRepository supplierRepository;
  final ShiftRepository shiftRepository;
  final AuditRepository auditRepository;
  final CashRepository cashRepository;
  final PrinterRepository printerRepository;
  final ValueNotifier<PosSettings> settingsNotifier;
  final AppCommandBus commandBus;
  final DatabaseGateway? databaseGateway;
}
