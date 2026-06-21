abstract final class DatabaseTables {
  static const accounts = 'accounts';
  static const credentials = 'credentials';
  static const ingredients = 'ingredients';
  static const inventoryTransactions = 'inventory_transactions';
  static const suppliers = 'suppliers';
  static const supplierTransactions = 'supplier_transactions';
  static const shifts = 'shifts';
  static const auditEvents = 'audit_events';
  static const menuCategories = 'menu_categories';
  static const menuItems = 'menu_items';
  static const itemSizes = 'item_sizes';
  static const itemAddons = 'item_addons';
  static const recipes = 'recipes';
  static const orders = 'orders';
  static const diningTables = 'dining_tables';
  static const settings = 'settings';
  static const floors = 'floors';
  static const cashDrawerTransactions = 'cash_drawer_transactions';
  static const kitchenPrinters = 'kitchen_printers';

  static const all = <String>{
    accounts,
    credentials,
    ingredients,
    inventoryTransactions,
    suppliers,
    supplierTransactions,
    shifts,
    auditEvents,
    menuCategories,
    menuItems,
    itemSizes,
    itemAddons,
    recipes,
    orders,
    diningTables,
    settings,
    floors,
    cashDrawerTransactions,
    kitchenPrinters,
  };

  static const managerV1 = <String>{
    accounts,
    credentials,
    ingredients,
    inventoryTransactions,
    suppliers,
    supplierTransactions,
    shifts,
    auditEvents,
  };

  static const menuV2 = <String>{
    menuCategories,
    menuItems,
    itemSizes,
    itemAddons,
    recipes,
  };

  static const operationsV3 = <String>{
    orders,
    diningTables,
    settings,
  };

  static const floorPlanV4 = <String>{floors};

  static const cashDrawerV5 = <String>{cashDrawerTransactions};

  static const printersV6 = <String>{kitchenPrinters};
}
