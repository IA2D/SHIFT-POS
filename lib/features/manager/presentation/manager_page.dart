// ignore_for_file: require_trailing_commas, prefer_const_constructors

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/printing/platform_print_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../audit/domain/audit_event.dart';
import '../../auth/domain/app_user.dart';
import '../../cash/domain/cash_drawer_transaction.dart';
import '../../inventory/domain/ingredient.dart';
import '../../inventory/domain/inventory_transaction.dart';
import '../../manager/application/manager_dashboard_service.dart';
import '../../menu/domain/menu_category.dart';
import '../../menu/domain/menu_item.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../printers/domain/kitchen_printer.dart';
import '../../receipt/application/receipt_text_builder.dart';
import '../../settings/domain/pos_settings.dart';
import '../../settings/presentation/manager_settings_panel.dart';
import '../../shifts/domain/shift.dart';
import '../../suppliers/domain/supplier.dart';
import '../../suppliers/domain/supplier_transaction.dart';
import '../../tables/domain/dining_table.dart';
import '../../tables/presentation/floor_plan_editor.dart';
import 'menu_item_editor_dialog.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  _ManagerSection _section = _ManagerSection.dashboard;
  late Future<_ManagerSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<_ManagerSnapshot> _loadSnapshot() async {
    final dependencies = AppStateScope.of(context);
    final dashboard = await ManagerDashboardService(
      orderRepository: dependencies.orderRepository,
    ).loadSummary();
    final categories = await dependencies.menuRepository.listCategories();
    final items =
        await dependencies.menuRepository.listItems(includeInactive: true);
    final sizes = await dependencies.menuRepository.listSizes();
    final addons = await dependencies.menuRepository.listAddons();
    final recipes = await dependencies.menuRepository.listRecipes();
    final tables = await dependencies.tableRepository.listTables();
    final orders = await dependencies.orderRepository.listOrders();
    final settings = await dependencies.settingsRepository.getPosSettings();
    final user = await dependencies.authRepository.currentUser();
    final accounts = await dependencies.authRepository.listAccounts();
    final ingredients =
        await dependencies.inventoryRepository.listIngredients();
    final ingredientStocks =
        await dependencies.inventoryRepository.listStocks();
    final inventoryTransactions =
        await dependencies.inventoryRepository.listTransactions();
    final suppliers = await dependencies.supplierRepository.listSuppliers();
    final supplierTransactions =
        await dependencies.supplierRepository.listTransactions();
    final shifts = await dependencies.shiftRepository.listShifts();
    final auditEvents = await dependencies.auditRepository.listEvents();
    final cashTransactions =
        await dependencies.cashRepository.listTransactions();
    final kitchenPrinters =
        await dependencies.printerRepository.listKitchenPrinters();

    return _ManagerSnapshot(
      dashboard: dashboard,
      categories: categories,
      items: items,
      sizes: sizes,
      addons: addons,
      recipes: recipes,
      tables: tables,
      orders: orders,
      settings: settings,
      currentUser: user,
      accounts: accounts,
      ingredients: ingredients,
      ingredientStocks: ingredientStocks,
      inventoryTransactions: inventoryTransactions,
      suppliers: suppliers,
      supplierTransactions: supplierTransactions,
      shifts: shifts,
      auditEvents: auditEvents,
      cashTransactions: cashTransactions,
      kitchenPrinters: kitchenPrinters,
    );
  }

  void _reload() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<void> _log(String action, String details) async {
    final dependencies = AppStateScope.of(context);
    final user = await dependencies.authRepository.currentUser();
    await dependencies.auditRepository.record(
      AuditEvent(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        action: action,
        actorUsername: user?.username ?? 'system',
        actorId: user?.id,
        createdAt: DateTime.now(),
        detailAr: details,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ManagerSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Row(
          children: [
            _ManagerSidebar(
              selected: _section,
              onSelected: (section) => setState(() => _section = section),
            ),
            Expanded(
              child: data == null
                  ? const Center(child: CircularProgressIndicator())
                  : _ManagerContent(
                      section: _section,
                      snapshot: data,
                      config: widget.config,
                      onReload: _reload,
                      onLog: _log,
                      onAddPurchase: (transaction, supplierTransaction) async {
                        final dependencies = AppStateScope.of(context);
                        await dependencies.inventoryRepository
                            .saveTransaction(transaction);
                        if (supplierTransaction != null) {
                          await dependencies.supplierRepository
                              .saveTransaction(supplierTransaction);
                        }
                        await _log(
                          'inventory_purchase',
                          transaction.noteAr ?? transaction.ingredientId,
                        );
                        if (mounted) _reload();
                      },
                      onCloseShift: (shift, closingCash) async {
                        final dependencies = AppStateScope.of(context);
                        final user =
                            await dependencies.authRepository.currentUser();
                        await dependencies.shiftRepository.saveShift(
                          shift.copyWith(
                            status: ShiftStatus.closed,
                            closedAt: DateTime.now(),
                            closedBy: user?.username ?? 'manager',
                            closingCash: closingCash,
                            updatedAt: DateTime.now(),
                          ),
                        );
                        await _log('shift_closed', shift.cashierName);
                        if (mounted) _reload();
                      },
                      onAddSupplier: (supplier) async {
                        final dependencies = AppStateScope.of(context);
                        await dependencies.supplierRepository
                            .saveSupplier(supplier);
                        await _log('supplier_created', supplier.nameAr);
                        if (mounted) _reload();
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ManagerContent extends StatelessWidget {
  const _ManagerContent({
    required this.section,
    required this.snapshot,
    required this.config,
    required this.onReload,
    required this.onLog,
    required this.onAddPurchase,
    required this.onCloseShift,
    required this.onAddSupplier,
  });

  final _ManagerSection section;
  final _ManagerSnapshot snapshot;
  final AppConfig config;
  final VoidCallback onReload;
  final Future<void> Function(String action, String details) onLog;
  final Future<void> Function(
    InventoryTransaction transaction,
    SupplierTransaction? supplierTransaction,
  ) onAddPurchase;
  final Future<void> Function(Shift shift, double closingCash) onCloseShift;
  final Future<void> Function(Supplier supplier) onAddSupplier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: switch (section) {
        _ManagerSection.dashboard => _DashboardSection(
            snapshot: snapshot,
            onReload: onReload,
            onNavigate: (_) {},
          ),
        _ManagerSection.items => _ItemsSection(
            categories: snapshot.categories,
            items: snapshot.items,
            sizes: snapshot.sizes,
            addons: snapshot.addons,
            recipes: snapshot.recipes,
            ingredients: snapshot.ingredients,
            kitchenPrinters: snapshot.kitchenPrinters,
            onChanged: onReload,
          ),
        _ManagerSection.tables => FloorPlanEditor(onChanged: onReload),
        _ManagerSection.purchases => _PurchasesSection(
            ingredients: snapshot.ingredients,
            transactions: snapshot.inventoryTransactions,
            stocks: snapshot.ingredientStocks,
            suppliers: snapshot.suppliers,
            onAdd: onAddPurchase,
            onChanged: onReload,
          ),
        _ManagerSection.accounts => _AccountsSection(
            accounts: snapshot.accounts,
            currentUser: snapshot.currentUser,
            onChanged: onReload,
            onLog: onLog,
          ),
        _ManagerSection.shifts => _ShiftsSection(
            shifts: snapshot.shifts,
            orders: snapshot.orders,
            inventoryTransactions: snapshot.inventoryTransactions,
            cashTransactions: snapshot.cashTransactions,
            onClose: onCloseShift,
            onChanged: onReload,
            onLog: onLog,
          ),
        _ManagerSection.suppliers => _SuppliersSection(
            suppliers: snapshot.suppliers,
            transactions: snapshot.supplierTransactions,
            onAdd: onAddSupplier,
            onChanged: onReload,
            onLog: onLog,
          ),
        _ManagerSection.cashierHistory => _CashierHistorySection(
            orders: snapshot.orders,
            onChanged: onReload,
            onLog: onLog,
          ),
        _ManagerSection.reports => _ReportsSection(
            snapshot: snapshot,
          ),
        _ManagerSection.audit => _AuditSection(audit: snapshot.auditEvents),
        _ManagerSection.settings => _SettingsManagerSection(
            settings: snapshot.settings,
            config: config,
            kitchenPrinters: snapshot.kitchenPrinters,
            onLog: onLog,
            onChanged: onReload,
          ),
      },
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.snapshot,
    required this.onReload,
    required this.onNavigate,
  });

  final _ManagerSnapshot snapshot;
  final VoidCallback onReload;
  final ValueChanged<_ManagerSection> onNavigate;

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.dashboard;
    return _PageScaffold(
      title: 'لوحة التحكم',
      subtitle: 'ملخص سريع ثم اختر القسم للإدارة',
      trailing: OutlinedButton.icon(
        onPressed: onReload,
        icon: const Icon(Icons.refresh),
        label: const Text('تحديث'),
      ),
      child: ListView(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                  title: 'طلبات اليوم', value: summary.orderCount.toString()),
              _MetricCard(
                  title: 'طلبات مدفوعة',
                  value: summary.paidOrderCount.toString()),
              _MetricCard(
                  title: 'صالة غير مدفوعة',
                  value: summary.unpaidDineInCount.toString()),
              _MetricCard(
                  title: 'إيرادات مدفوعة',
                  value: summary.salesTotal.toStringAsFixed(2)),
            ],
          ),
          const SizedBox(height: 14),
          _SectionGrid(
            sections: _ManagerSection.values
                .where((section) => section != _ManagerSection.dashboard)
                .toList(),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'آخر الطلبات',
            child: _OrdersTable(orders: summary.recentOrders),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  const _ItemsSection({
    required this.categories,
    required this.items,
    required this.sizes,
    required this.addons,
    required this.recipes,
    required this.ingredients,
    required this.kitchenPrinters,
    required this.onChanged,
  });

  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final List<ItemSize> sizes;
  final List<ItemAddon> addons;
  final List<Recipe> recipes;
  final List<Ingredient> ingredients;
  final List<KitchenPrinter> kitchenPrinters;
  final VoidCallback onChanged;

  Future<void> _moveCategory(
      BuildContext context, MenuCategory category, int direction) async {
    final ordered = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = ordered.indexWhere((value) => value.id == category.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    final repository = AppStateScope.of(context).menuRepository;
    for (var order = 0; order < ordered.length; order++) {
      await repository.saveCategory(ordered[order].copyWith(sortOrder: order));
    }
    onChanged();
  }

  Future<void> _moveSize(
      BuildContext context, ItemSize size, int direction) async {
    final ordered = [...sizes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = ordered.indexWhere((value) => value.id == size.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    final repository = AppStateScope.of(context).menuRepository;
    for (var order = 0; order < ordered.length; order++) {
      final value = ordered[order];
      await repository.saveSize(ItemSize(
        id: value.id,
        nameAr: value.nameAr,
        sortOrder: order,
        active: value.active,
      ));
    }
    onChanged();
  }

  Future<void> _moveAddon(
      BuildContext context, ItemAddon addon, int direction) async {
    final ordered = [...addons]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index = ordered.indexWhere((value) => value.id == addon.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= ordered.length) return;
    final moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    final repository = AppStateScope.of(context).menuRepository;
    for (var order = 0; order < ordered.length; order++) {
      final value = ordered[order];
      await repository.saveAddon(ItemAddon(
        id: value.id,
        nameAr: value.nameAr,
        defaultPrice: value.defaultPrice,
        sortOrder: order,
        active: value.active,
      ));
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final itemsByCategory = {
      for (final category in categories)
        category.id:
            items.where((item) => item.categoryId == category.id).toList(),
    };
    return _PageScaffold(
      title: 'الأصناف',
      subtitle: 'القائمة والتصنيفات والأحجام والإضافات والوصفات',
      child: ListView(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(title: 'الأصناف', value: items.length.toString()),
              _MetricCard(
                  title: 'التصنيفات', value: categories.length.toString()),
              _MetricCard(title: 'الأحجام', value: sizes.length.toString()),
              _MetricCard(title: 'الإضافات', value: addons.length.toString()),
              _MetricCard(title: 'الوصفات', value: recipes.length.toString()),
            ],
          ),
          const SizedBox(height: 14),
          _MenuCrudToolbar(
            categories: categories,
            sizes: sizes,
            addons: addons,
            ingredients: ingredients,
            kitchenPrinters: kitchenPrinters,
            onChanged: onChanged,
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'التصنيفات',
            child: Column(
              children: categories.asMap().entries.map((entry) {
                final category = entry.value;
                final parent = categories
                    .where((value) => value.id == category.parentId)
                    .firstOrNull;
                return _CatalogEntityRow(
                  title: category.nameAr,
                  subtitle: [
                    '${itemsByCategory[category.id]?.length ?? 0} صنف',
                    if (parent != null) 'داخل ${parent.nameAr}',
                  ].join(' · '),
                  active: category.active,
                  canMoveUp: entry.key > 0,
                  canMoveDown: entry.key < categories.length - 1,
                  onMoveUp: () => _moveCategory(context, category, -1),
                  onMoveDown: () => _moveCategory(context, category, 1),
                  onEdit: () => _showCategoryEditDialog(
                    context,
                    category,
                    categories,
                    onChanged,
                  ),
                  onToggle: () async {
                    await AppStateScope.of(context).menuRepository.saveCategory(
                        category.copyWith(active: !category.active));
                    onChanged();
                  },
                  onDelete: () => _deleteCatalogEntity(
                    context,
                    title: category.nameAr,
                    delete: () => AppStateScope.of(context)
                        .menuRepository
                        .deleteCategory(category.id),
                    onChanged: onChanged,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'الأصناف',
            child: _MenuItemsTable(
              items: items,
              categories: categories,
              recipes: recipes,
              sizes: sizes,
              addons: addons,
              ingredients: ingredients,
              kitchenPrinters: kitchenPrinters,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'الأحجام والإضافات',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: Column(
                    children: sizes.asMap().entries.map((entry) {
                      final size = entry.value;
                      return _CatalogEntityRow(
                        title: size.nameAr,
                        active: size.active,
                        canMoveUp: entry.key > 0,
                        canMoveDown: entry.key < sizes.length - 1,
                        onMoveUp: () => _moveSize(context, size, -1),
                        onMoveDown: () => _moveSize(context, size, 1),
                        onEdit: () =>
                            _showSizeEditDialog(context, size, onChanged),
                        onToggle: () async {
                          await AppStateScope.of(context)
                              .menuRepository
                              .saveSize(ItemSize(
                                id: size.id,
                                nameAr: size.nameAr,
                                sortOrder: size.sortOrder,
                                active: !size.active,
                              ));
                          onChanged();
                        },
                        onDelete: () => _deleteCatalogEntity(
                          context,
                          title: size.nameAr,
                          delete: () => AppStateScope.of(context)
                              .menuRepository
                              .deleteSize(size.id),
                          onChanged: onChanged,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: Column(
                    children: addons.asMap().entries.map((entry) {
                      final addon = entry.value;
                      return _CatalogEntityRow(
                        title: addon.nameAr,
                        subtitle: addon.defaultPrice.toStringAsFixed(2),
                        active: addon.active,
                        canMoveUp: entry.key > 0,
                        canMoveDown: entry.key < addons.length - 1,
                        onMoveUp: () => _moveAddon(context, addon, -1),
                        onMoveDown: () => _moveAddon(context, addon, 1),
                        onEdit: () =>
                            _showAddonEditDialog(context, addon, onChanged),
                        onToggle: () async {
                          await AppStateScope.of(context)
                              .menuRepository
                              .saveAddon(ItemAddon(
                                id: addon.id,
                                nameAr: addon.nameAr,
                                defaultPrice: addon.defaultPrice,
                                sortOrder: addon.sortOrder,
                                active: !addon.active,
                              ));
                          onChanged();
                        },
                        onDelete: () => _deleteCatalogEntity(
                          context,
                          title: addon.nameAr,
                          delete: () => AppStateScope.of(context)
                              .menuRepository
                              .deleteAddon(addon.id),
                          onChanged: onChanged,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogEntityRow extends StatelessWidget {
  const _CatalogEntityRow({
    required this.title,
    required this.active,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'أعلى',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: 'أسفل',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(color: AppTheme.muted)),
              ],
            ),
          ),
          Text(active ? 'مفعل' : 'معطل'),
          IconButton(
            tooltip: 'تعديل',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: active ? 'تعطيل' : 'تفعيل',
            onPressed: onToggle,
            icon: Icon(
                active ? Icons.toggle_on_outlined : Icons.toggle_off_outlined),
          ),
          IconButton(
            tooltip: 'حذف',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteCatalogEntity(
  BuildContext context, {
  required String title,
  required Future<void> Function() delete,
  required VoidCallback onChanged,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text('هل تريد حذف "$title"؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await delete();
    onChanged();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحذف: $error')),
      );
    }
  }
}

Future<void> _showCategoryEditDialog(
  BuildContext context,
  MenuCategory category,
  List<MenuCategory> categories,
  VoidCallback onChanged,
) async {
  final name = TextEditingController(text: category.nameAr);
  var parentId = category.parentId;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل تصنيف'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'اسم التصنيف'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: parentId,
              decoration: const InputDecoration(labelText: 'المجموعة الأعلى'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('تصنيف رئيسي'),
                ),
                ...categories
                    .where((value) =>
                        value.id != category.id && value.parentId == null)
                    .map((value) => DropdownMenuItem<String?>(
                          value: value.id,
                          child: Text(value.nameAr),
                        )),
              ],
              onChanged: (value) => parentId = value,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await AppStateScope.of(context).menuRepository.saveCategory(
                  MenuCategory(
                    id: category.id,
                    nameAr: name.text.trim(),
                    parentId: parentId,
                    sortOrder: category.sortOrder,
                    active: category.active,
                    createdAt: category.createdAt,
                    updatedAt: DateTime.now(),
                  ),
                );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

Future<void> _showSizeEditDialog(
  BuildContext context,
  ItemSize size,
  VoidCallback onChanged,
) async {
  final name = TextEditingController(text: size.nameAr);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل حجم'),
      content: TextField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'اسم الحجم'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await AppStateScope.of(context).menuRepository.saveSize(ItemSize(
                  id: size.id,
                  nameAr: name.text.trim(),
                  sortOrder: size.sortOrder,
                  active: size.active,
                ));
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

Future<void> _showAddonEditDialog(
  BuildContext context,
  ItemAddon addon,
  VoidCallback onChanged,
) async {
  final name = TextEditingController(text: addon.nameAr);
  final price =
      TextEditingController(text: addon.defaultPrice.toStringAsFixed(2));
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تعديل إضافة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الإضافة'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'السعر الافتراضي'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            await AppStateScope.of(context).menuRepository.saveAddon(ItemAddon(
                  id: addon.id,
                  nameAr: name.text.trim(),
                  defaultPrice: double.tryParse(price.text.trim()) ?? 0,
                  sortOrder: addon.sortOrder,
                  active: addon.active,
                ));
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class _MenuCrudToolbar extends StatelessWidget {
  const _MenuCrudToolbar({
    required this.categories,
    required this.sizes,
    required this.addons,
    required this.ingredients,
    required this.kitchenPrinters,
    required this.onChanged,
  });

  final List<MenuCategory> categories;
  final List<ItemSize> sizes;
  final List<ItemAddon> addons;
  final List<Ingredient> ingredients;
  final List<KitchenPrinter> kitchenPrinters;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: 'إضافة سريعة',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () =>
                _showCategoryDialog(context, categories, onChanged),
            icon: const Icon(Icons.category),
            label: const Text('تصنيف'),
          ),
          FilledButton.icon(
            onPressed: categories.isEmpty
                ? null
                : () => showMenuItemEditorDialog(
                      context,
                      categories: categories,
                      sizes: sizes,
                      addons: addons,
                      ingredients: ingredients,
                      kitchenPrinters: kitchenPrinters,
                      onSaved: () async => onChanged(),
                    ),
            icon: const Icon(Icons.menu_book),
            label: const Text('صنف'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showSizeDialog(context, sizes, onChanged),
            icon: const Icon(Icons.straighten),
            label: const Text('حجم'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showAddonDialog(context, addons, onChanged),
            icon: const Icon(Icons.add_box),
            label: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCategoryDialog(
  BuildContext context,
  List<MenuCategory> categories,
  VoidCallback onChanged,
) async {
  final name = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إضافة تصنيف'),
      content: TextField(
        controller: name,
        decoration: const InputDecoration(labelText: 'اسم التصنيف'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final now = DateTime.now();
            await AppStateScope.of(context).menuRepository.saveCategory(
                  MenuCategory(
                    id: 'cat-${now.microsecondsSinceEpoch}',
                    nameAr: name.text.trim(),
                    sortOrder: categories.length + 1,
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

// Kept temporarily for compatibility while the richer editor is rolled out.
// ignore: unused_element
Future<void> _showItemDialog(
  BuildContext context,
  List<MenuCategory> categories,
  List<ItemSize> sizes,
  List<ItemAddon> addons,
  VoidCallback onChanged, {
  MenuItem? existing,
}) async {
  final name = TextEditingController(text: existing?.nameAr ?? '');
  final price =
      TextEditingController(text: existing?.price.toStringAsFixed(2) ?? '');
  var categoryId = existing?.categoryId ?? categories.first.id;
  var itemType = existing?.itemType ?? MenuItemType.product;
  var productType = existing?.productType ?? ProductType.recipe;
  var isWeighted = existing?.isWeighted ?? false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'إضافة صنف' : 'تعديل صنف'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الصنف'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'السعر'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: categories
                      .map((category) => DropdownMenuItem(
                          value: category.id, child: Text(category.nameAr)))
                      .toList(),
                  onChanged: (value) => categoryId = value ?? categoryId,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MenuItemType>(
                  initialValue: itemType,
                  decoration: const InputDecoration(labelText: 'نوع الصنف'),
                  items: MenuItemType.values
                      .map((type) => DropdownMenuItem(
                          value: type, child: Text(_menuItemTypeName(type))))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => itemType = value ?? itemType),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ProductType>(
                  initialValue: productType,
                  decoration: const InputDecoration(labelText: 'نوع المنتج'),
                  items: ProductType.values
                      .map((type) => DropdownMenuItem(
                          value: type, child: Text(_productTypeName(type))))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => productType = value ?? productType),
                ),
                CheckboxListTile(
                  value: isWeighted,
                  title: const Text('منتج ميزان'),
                  onChanged: (value) =>
                      setDialogState(() => isWeighted = value ?? false),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final now = DateTime.now();
              final item = MenuItem(
                id: existing?.id ?? 'item-${now.microsecondsSinceEpoch}',
                categoryId: categoryId,
                nameAr: name.text.trim(),
                price: double.tryParse(price.text.trim()) ?? 0,
                itemType: itemType,
                productType: productType,
                isWeighted: isWeighted,
                weightedPriceOptions: isWeighted
                    ? const [
                        WeightedPriceOption(
                            id: 'kg', label: '1 كجم', weightKg: 1, price: 0)
                      ]
                    : const [],
                sizeOptions: existing?.sizeOptions ?? const [],
                attachments: existing?.attachments ?? const [],
                recipeId: existing?.recipeId ??
                    'recipe-item-${now.microsecondsSinceEpoch}',
                sortOrder: existing?.sortOrder ?? 0,
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              );
              await AppStateScope.of(context).menuRepository.saveItem(item);
              onChanged();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showSizeDialog(
  BuildContext context,
  List<ItemSize> sizes,
  VoidCallback onChanged,
) async {
  final name = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إضافة حجم'),
      content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'اسم الحجم')),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final now = DateTime.now();
            await AppStateScope.of(context).menuRepository.saveSize(
                  ItemSize(
                      id: 'size-${now.microsecondsSinceEpoch}',
                      nameAr: name.text.trim(),
                      sortOrder: sizes.length + 1),
                );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

Future<void> _showAddonDialog(
  BuildContext context,
  List<ItemAddon> addons,
  VoidCallback onChanged,
) async {
  final name = TextEditingController();
  final price = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إضافة إضافة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'اسم الإضافة')),
          const SizedBox(height: 8),
          TextField(
              controller: price,
              decoration: const InputDecoration(labelText: 'السعر الافتراضي'),
              keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء')),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty) return;
            final now = DateTime.now();
            await AppStateScope.of(context).menuRepository.saveAddon(
                  ItemAddon(
                    id: 'addon-${now.microsecondsSinceEpoch}',
                    nameAr: name.text.trim(),
                    defaultPrice: double.tryParse(price.text.trim()) ?? 0,
                    sortOrder: addons.length + 1,
                  ),
                );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _TablesSection extends StatelessWidget {
  const _TablesSection({required this.tables, required this.onChanged});

  final List<DiningTable> tables;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final sections = <String, List<DiningTable>>{};
    for (final table in tables) {
      sections.putIfAbsent(table.sectionAr, () => []).add(table);
    }
    return _PageScaffold(
      title: 'الترابيزات',
      subtitle: 'تخطيط الصالة والمناطق',
      trailing: FilledButton.icon(
        onPressed: () => _showTableDialog(context, tables, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('ترابيزة'),
      ),
      child: ListView(
        children: [
          for (final entry in sections.entries) ...[
            _DataPanel(
              title: entry.key,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: entry.value
                    .map(
                      (table) => InkWell(
                        onTap: () => _showTableDialog(
                          context,
                          tables,
                          onChanged,
                          existing: table,
                        ),
                        child: Container(
                          width: 120,
                          height: 82,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            border: Border.all(
                                color: AppTheme.primaryDark, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                  offset: Offset(2, 2),
                                  color: Color(0x33000000)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  table.nameAr,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: IconButton(
                                  tooltip: 'حذف',
                                  color: Colors.white,
                                  iconSize: 17,
                                  onPressed: () => _deleteCatalogEntity(
                                    context,
                                    title: table.nameAr,
                                    delete: () => AppStateScope.of(context)
                                        .tableRepository
                                        .deleteTable(table.id),
                                    onChanged: onChanged,
                                  ),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
Future<void> _showTableDialog(
  BuildContext context,
  List<DiningTable> tables,
  VoidCallback onChanged, {
  DiningTable? existing,
}) async {
  final name = TextEditingController(text: existing?.nameAr ?? '');
  final section = TextEditingController(text: existing?.sectionAr ?? 'الصالة');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(existing == null ? 'إضافة ترابيزة' : 'تعديل ترابيزة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم الترابيزة'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: section,
            decoration: const InputDecoration(labelText: 'المنطقة'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty || section.text.trim().isEmpty) return;
            final now = DateTime.now();
            await AppStateScope.of(context).tableRepository.saveTable(
                  DiningTable(
                    id: existing?.id ?? 'table-${now.microsecondsSinceEpoch}',
                    nameAr: name.text.trim(),
                    sectionAr: section.text.trim(),
                    sortOrder: existing?.sortOrder ?? tables.length + 1,
                  ),
                );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class _PurchasesSection extends StatefulWidget {
  const _PurchasesSection({
    required this.ingredients,
    required this.transactions,
    required this.stocks,
    required this.suppliers,
    required this.onAdd,
    required this.onChanged,
  });

  final List<Ingredient> ingredients;
  final List<InventoryTransaction> transactions;
  final List<IngredientStock> stocks;
  final List<Supplier> suppliers;
  final Future<void> Function(
    InventoryTransaction transaction,
    SupplierTransaction? supplierTransaction,
  ) onAdd;
  final VoidCallback onChanged;

  @override
  State<_PurchasesSection> createState() => _PurchasesSectionState();
}

class _PurchasesSectionState extends State<_PurchasesSection> {
  final _quantity = TextEditingController();
  final _debt = TextEditingController();
  final _note = TextEditingController();
  String? _ingredientId;
  String? _supplierId;
  _PurchasesTab _tab = _PurchasesTab.stock;
  bool _submitting = false;

  @override
  void dispose() {
    _quantity.dispose();
    _debt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ingredientId = _ingredientId;
    IngredientStock? stock;
    for (final item in widget.stocks) {
      if (item.ingredientId == ingredientId) {
        stock = item;
        break;
      }
    }
    final quantity = double.tryParse(_quantity.text) ?? 0;
    if (stock == null || quantity <= 0 || _submitting) return;
    setState(() => _submitting = true);
    await widget.onAdd(
      InventoryTransaction(
        id: 'inventory-${DateTime.now().microsecondsSinceEpoch}',
        ingredientId: stock.ingredientId,
        ingredientNameAr: stock.nameAr,
        quantityDelta: quantity,
        unit: stock.unit,
        type: InventoryTransactionType.purchase,
        createdAt: DateTime.now(),
        referenceType: InventoryReferenceType.purchase,
        supplierId: _supplierId,
        noteAr: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdBy: 'manager',
      ),
      _supplierId != null && (double.tryParse(_debt.text) ?? 0) > 0
          ? SupplierTransaction(
              id: 'supplier-tx-${DateTime.now().microsecondsSinceEpoch}',
              supplierId: _supplierId!,
              amountDelta: double.tryParse(_debt.text) ?? 0,
              type: SupplierTransactionType.purchaseDebtIncrease,
              createdAt: DateTime.now(),
              noteAr: _note.text.trim().isEmpty
                  ? 'توريد مخزون: ${stock.nameAr}'
                  : _note.text.trim(),
              createdBy: 'manager',
            )
          : null,
    );
    _quantity.clear();
    _debt.clear();
    _note.clear();
    if (mounted) {
      setState(() {
        _ingredientId = null;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'المشتريات',
      subtitle: 'مخزون وشراء وهدر',
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<_PurchasesTab>(
              segments: [
                ButtonSegment(
                  value: _PurchasesTab.stock,
                  icon: const Icon(Icons.inventory_2),
                  label: Text(
                    widget.stocks.where((stock) => stock.isLow).isEmpty
                        ? 'المخزون الحالي'
                        : 'المخزون الحالي (${widget.stocks.where((stock) => stock.isLow).length})',
                  ),
                ),
                const ButtonSegment(
                  value: _PurchasesTab.ingredients,
                  icon: Icon(Icons.kitchen),
                  label: Text('المكوّنات'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tab == _PurchasesTab.stock
                ? _buildStockTab(context)
                : _buildIngredientsTab(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab(BuildContext context) {
    final lowStocks = widget.stocks.where((stock) => stock.isLow).toList();
    return ListView(
      children: [
        if (lowStocks.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xfffff4d6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xffa76200)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${lowStocks.length} مكوّن وصل لحد التنبيه — راجع المخزون وقم بالشراء',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        _DataPanel(
          title: 'تسجيل شراء سريع',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: _ingredientId,
                  decoration: const InputDecoration(labelText: 'المكوّن'),
                  items: widget.ingredients
                      .where((ingredient) => ingredient.active)
                      .map(
                        (ingredient) => DropdownMenuItem(
                          value: ingredient.id,
                          child: Text(
                            '${ingredient.nameAr} (${ingredient.unit})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _ingredientId = value),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String?>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(labelText: 'المورد'),
                  items: [
                    const DropdownMenuItem<String?>(
                      child: Text('بدون مورد'),
                    ),
                    ...widget.suppliers
                        .where((supplier) => supplier.active)
                        .map(
                          (supplier) => DropdownMenuItem<String?>(
                            value: supplier.id,
                            child: Text(supplier.nameAr),
                          ),
                        ),
                  ],
                  onChanged: (value) => setState(() => _supplierId = value),
                ),
              ),
              _SmallField(
                controller: _quantity,
                label: 'الكمية المشتراة',
                width: 150,
              ),
              _SmallField(
                controller: _debt,
                label: 'مديونية المورد',
                width: 150,
              ),
              _SmallField(
                controller: _note,
                label: 'ملاحظة',
                width: 210,
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.add),
                label: const Text('تسجيل شراء'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DataPanel(
          title: 'المخزون الحالي (محسوب من جميع الحركات)',
          child: _SimpleTable(
            columns: const [
              'المكوّن',
              'الرصيد',
              'الوحدة',
              'حد التنبيه',
              'الحالة',
            ],
            rows: widget.stocks
                .map(
                  (stock) => [
                    stock.nameAr,
                    stock.quantity.toStringAsFixed(2),
                    stock.unit,
                    stock.lowStockThreshold?.toStringAsFixed(2) ?? '—',
                    stock.isLow ? 'نفاد قريب' : 'متوفر',
                  ],
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _DataPanel(
          title: 'إجراءات المخزون',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stock in widget.stocks)
                _InventoryActionRow(
                  stock: stock,
                  onPurchase: () =>
                      setState(() => _ingredientId = stock.ingredientId),
                  onAdjustment: () => _showMovementDialog(
                      stock, InventoryTransactionType.adjustment),
                  onWaste: () => _showMovementDialog(
                      stock, InventoryTransactionType.waste),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsTab(BuildContext context) {
    return ListView(
      children: [
        _DataPanel(
          title: 'المكوّنات (${widget.ingredients.length})',
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: () => _showIngredientDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة مكوّن'),
                ),
              ),
              const SizedBox(height: 10),
              for (final ingredient in widget.ingredients)
                _ListRow(
                  title: ingredient.nameAr,
                  subtitle:
                      '${ingredient.unit} • حد التنبيه ${ingredient.lowStockThreshold?.toStringAsFixed(2) ?? '—'}',
                  trailingWidget: Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showIngredientDialog(ingredient),
                        child: const Text('تعديل'),
                      ),
                      IconButton(
                        tooltip: ingredient.active ? 'تعطيل' : 'تفعيل',
                        onPressed: () => _toggleIngredient(ingredient),
                        icon: Icon(
                          ingredient.active
                              ? Icons.toggle_on
                              : Icons.toggle_off,
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        onPressed: () => _deleteIngredient(ingredient),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showMovementDialog(
    IngredientStock stock,
    InventoryTransactionType type,
  ) async {
    final quantity = TextEditingController();
    final note = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(type == InventoryTransactionType.waste
            ? 'تسجيل هدر — ${stock.nameAr}'
            : 'تسوية المخزون — ${stock.nameAr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: type == InventoryTransactionType.waste
                    ? 'الكمية المهدرة'
                    : 'فرق الكمية (+ أو -)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final entered = double.tryParse(quantity.text) ?? 0;
              if (entered == 0) return;
              await widget.onAdd(
                InventoryTransaction(
                  id: 'inventory-${DateTime.now().microsecondsSinceEpoch}',
                  ingredientId: stock.ingredientId,
                  ingredientNameAr: stock.nameAr,
                  quantityDelta: type == InventoryTransactionType.waste
                      ? -entered.abs()
                      : entered,
                  unit: stock.unit,
                  type: type,
                  createdAt: DateTime.now(),
                  referenceType: InventoryReferenceType.manual,
                  noteAr: note.text.trim().isEmpty ? null : note.text.trim(),
                  createdBy: 'manager',
                ),
                null,
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showIngredientDialog([Ingredient? existing]) async {
    final name = TextEditingController(text: existing?.nameAr ?? '');
    final threshold = TextEditingController(
      text: existing?.lowStockThreshold?.toString() ?? '',
    );
    var unit = existing?.unit ?? 'جرام';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'إضافة مكوّن جديد' : 'تعديل المكوّن'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'وحدة القياس'),
                items: const ['جرام', 'كيلوجرام', 'قطعة', 'مل', 'لتر']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => unit = value ?? unit),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: threshold,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'حد التنبيه (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final now = DateTime.now();
                await AppStateScope.of(context)
                    .inventoryRepository
                    .saveIngredient(
                      Ingredient(
                        id: existing?.id ??
                            'ingredient-${now.microsecondsSinceEpoch}',
                        nameAr: name.text.trim(),
                        unit: unit,
                        lowStockThreshold:
                            double.tryParse(threshold.text.trim()),
                        active: existing?.active ?? true,
                        createdAt: existing?.createdAt ?? now,
                        updatedAt: now,
                      ),
                    );
                widget.onChanged();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleIngredient(Ingredient ingredient) async {
    await AppStateScope.of(context).inventoryRepository.saveIngredient(
          ingredient.copyWith(
            active: !ingredient.active,
            updatedAt: DateTime.now(),
          ),
        );
    widget.onChanged();
  }

  Future<void> _deleteIngredient(Ingredient ingredient) async {
    await AppStateScope.of(context)
        .inventoryRepository
        .deleteIngredient(ingredient.id);
    widget.onChanged();
  }
}

enum _PurchasesTab { stock, ingredients }

class _InventoryActionRow extends StatelessWidget {
  const _InventoryActionRow({
    required this.stock,
    required this.onPurchase,
    required this.onAdjustment,
    required this.onWaste,
  });

  final IngredientStock stock;
  final VoidCallback onPurchase;
  final VoidCallback onAdjustment;
  final VoidCallback onWaste;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderLight),
        color: stock.isLow ? const Color(0xfffffbeb) : Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${stock.nameAr} — ${stock.quantity.toStringAsFixed(2)} ${stock.unit}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'شراء',
            onPressed: onPurchase,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'تسوية',
            onPressed: onAdjustment,
            icon: const Icon(Icons.swap_vert),
          ),
          IconButton(
            tooltip: 'هدر',
            onPressed: onWaste,
            icon: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class _AccountsSection extends StatefulWidget {
  const _AccountsSection({
    required this.accounts,
    required this.currentUser,
    required this.onChanged,
    required this.onLog,
  });

  final List<AppUser> accounts;
  final AppUser? currentUser;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<_AccountsSection> createState() => _AccountsSectionState();
}

class _AccountsSectionState extends State<_AccountsSection> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _cashierCode = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.cashier;
  Set<Permission> _permissions = _permissionsForRole(UserRole.cashier);
  _AccountsTab _tab = _AccountsTab.accounts;
  bool _showCreate = false;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _cashierCode.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty ||
        _displayName.text.trim().isEmpty ||
        _password.text.length < 6 ||
        _permissions.isEmpty ||
        _saving) {
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final user = AppUser(
      id: 'user-${now.microsecondsSinceEpoch}',
      username: _username.text.trim(),
      displayName: _displayName.text.trim(),
      role: _role,
      permissions: {..._permissions},
      cashierCode: _cashierCode.text.trim().isEmpty
          ? null
          : _cashierCode.text.trim().toUpperCase(),
    );
    await AppStateScope.of(context).authRepository.saveAccount(
          user,
          password: _password.text,
        );
    await widget.onLog('account_created', user.username);
    widget.onChanged();
    _username.clear();
    _displayName.clear();
    _cashierCode.clear();
    _password.clear();
    if (mounted) {
      setState(() {
        _saving = false;
        _showCreate = false;
      });
    }
  }

  void _setRole(UserRole role) {
    setState(() {
      _role = role;
      _permissions = _permissionsForRole(role);
    });
  }

  Future<void> _saveAccount(AppUser user, String action) async {
    await AppStateScope.of(context).authRepository.saveAccount(user);
    await widget.onLog(action, user.username);
    widget.onChanged();
  }

  Future<void> _deleteAccount(AppUser user) async {
    if (user.id == widget.currentUser?.id) return;
    await AppStateScope.of(context).authRepository.deleteAccount(user.id);
    await widget.onLog('account_deleted', user.username);
    widget.onChanged();
  }

  Future<void> _showPasswordDialog(AppUser user) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تغيير كلمة مرور ${user.displayName}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.length < 6) return;
              await AppStateScope.of(context)
                  .authRepository
                  .setPassword(user.id, controller.text);
              await widget.onLog('account_password_changed', user.username);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinDialog(AppUser user) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('PIN — ${user.displayName}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '4 أرقام — اتركه فارغاً للحذف',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final pin = controller.text.trim();
              if (pin.isNotEmpty &&
                  (pin.length != 4 || int.tryParse(pin) == null)) {
                return;
              }
              await AppStateScope.of(context)
                  .authRepository
                  .setPin(user.id, pin.isEmpty ? null : pin);
              await widget.onLog('account_pin_changed', user.username);
              widget.onChanged();
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'الحسابات',
      subtitle: 'المستخدمون والصلاحيات',
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<_AccountsTab>(
              segments: [
                ButtonSegment(
                  value: _AccountsTab.accounts,
                  icon: const Icon(Icons.people),
                  label: Text('الحسابات (${widget.accounts.length})'),
                ),
                const ButtonSegment(
                  value: _AccountsTab.permissions,
                  icon: Icon(Icons.shield),
                  label: Text('دليل الصلاحيات'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tab == _AccountsTab.accounts
                ? _buildAccountsTab()
                : _buildPermissionGuide(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTab() {
    return ListView(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: () => setState(() => _showCreate = !_showCreate),
            icon: Icon(_showCreate ? Icons.close : Icons.person_add),
            label: Text(_showCreate ? 'إلغاء' : 'إضافة حساب جديد'),
          ),
        ),
        if (_showCreate) ...[
          const SizedBox(height: 12),
          _DataPanel(
            title: 'إنشاء حساب جديد',
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallField(
                      controller: _displayName,
                      label: 'الاسم الكامل',
                    ),
                    _SmallField(
                      controller: _username,
                      label: 'اسم المستخدم',
                    ),
                    _SmallField(
                      controller: _cashierCode,
                      label: 'كود الإيصال',
                      width: 120,
                    ),
                    _SmallField(
                      controller: _password,
                      label: 'كلمة المرور',
                    ),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<UserRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'الدور'),
                        items: UserRole.values
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(_roleLabel(role)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            _setRole(value ?? UserRole.cashier),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PermissionPicker(
                  permissions: _permissions,
                  onChanged: (value) => setState(() => _permissions = value),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: Text(_saving ? 'جارٍ الإنشاء...' : 'إنشاء الحساب'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final user in widget.accounts)
          _DataPanel(
            title: user.displayName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('@${user.username}'),
                    Chip(label: Text(_roleLabel(user.role))),
                    if (user.cashierCode != null)
                      Chip(label: Text(user.cashierCode!)),
                    if (user.pin != null) const Chip(label: Text('PIN ✓')),
                    Chip(label: Text('${user.permissions.length} صلاحية')),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _saveAccount(
                        user.copyWith(active: !user.active),
                        'account_active_changed',
                      ),
                      icon: Icon(
                        user.active ? Icons.toggle_on : Icons.toggle_off,
                      ),
                      label: Text(user.active ? 'مفعّل' : 'معطّل'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPasswordDialog(user),
                      icon: const Icon(Icons.lock),
                      label: const Text('كلمة المرور'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPinDialog(user),
                      icon: const Icon(Icons.shield),
                      label: const Text('PIN'),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: user.id == widget.currentUser?.id
                          ? null
                          : () => _deleteAccount(user),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionGuide() {
    return ListView(
      children: [
        for (final role in UserRole.values)
          _DataPanel(
            title: _roleLabel(role),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _permissionsForRole(role)
                  .map(
                    (permission) =>
                        Chip(label: Text(_permissionLabel(permission))),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

enum _AccountsTab { accounts, permissions }

class _PermissionPicker extends StatelessWidget {
  const _PermissionPicker({
    required this.permissions,
    required this.onChanged,
  });

  final Set<Permission> permissions;
  final ValueChanged<Set<Permission>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Permission.values
          .map(
            (permission) => FilterChip(
              selected: permissions.contains(permission),
              label: Text(_permissionLabel(permission)),
              onSelected: (selected) {
                final next = {...permissions};
                selected ? next.add(permission) : next.remove(permission);
                onChanged(next);
              },
            ),
          )
          .toList(),
    );
  }
}

class _ShiftsSection extends StatefulWidget {
  const _ShiftsSection({
    required this.shifts,
    required this.orders,
    required this.inventoryTransactions,
    required this.cashTransactions,
    required this.onClose,
    required this.onChanged,
    required this.onLog,
  });

  final List<Shift> shifts;
  final List<Order> orders;
  final List<InventoryTransaction> inventoryTransactions;
  final List<CashDrawerTransaction> cashTransactions;
  final Future<void> Function(Shift shift, double closingCash) onClose;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<_ShiftsSection> createState() => _ShiftsSectionState();
}

class _ShiftsSectionState extends State<_ShiftsSection> {
  bool _showArchived = false;
  Shift? _selected;

  List<Order> _ordersForShift(Shift shift) {
    final end = shift.closedAt ?? DateTime.now();
    return widget.orders.where((order) {
      if (order.shiftId == shift.id) return true;
      if (order.shiftId != null) return false;
      final inWindow = !order.createdAt.isBefore(shift.openedAt) &&
          !order.createdAt.isAfter(end);
      final matchesCashier = order.cashierId == shift.cashierId ||
          (order.cashierName?.trim().toLowerCase() ==
              shift.cashierName.trim().toLowerCase());
      return inWindow && matchesCashier;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  List<CashDrawerTransaction> _cashForShift(Shift shift) {
    final end = shift.closedAt ?? DateTime.now();
    return widget.cashTransactions.where((transaction) {
      if (transaction.shiftId == shift.id) return true;
      if (transaction.shiftId != null) return false;
      return transaction.createdBy == shift.cashierId &&
          !transaction.createdAt.isBefore(shift.openedAt) &&
          !transaction.createdAt.isAfter(end);
    }).toList();
  }

  List<InventoryTransaction> _inventoryForShift(
    Shift shift,
    Set<String> orderIds,
  ) {
    final end = shift.closedAt ?? DateTime.now();
    return widget.inventoryTransactions.where((transaction) {
      if (transaction.shiftId == shift.id) return true;
      if (transaction.shiftId != null) return false;
      if (transaction.referenceId != null &&
          orderIds.contains(transaction.referenceId)) {
        return true;
      }
      return transaction.createdBy == shift.cashierId &&
          !transaction.createdAt.isBefore(shift.openedAt) &&
          !transaction.createdAt.isAfter(end);
    }).toList();
  }

  double _expectedCash(Shift shift) {
    final cashSales = _ordersForShift(shift)
        .where((order) => order.status == OrderStatus.paid)
        .fold<double>(0, (sum, order) => sum + (order.cashPaid ?? 0));
    final movements = _cashForShift(shift)
        .where(
            (transaction) => transaction.type != CashDrawerTransactionType.sale)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    return (shift.openingCash ?? 0) + cashSales + movements;
  }

  Future<void> _closeShift(Shift shift) async {
    final expected = _expectedCash(shift);
    final unpaid = _ordersForShift(shift)
        .where((order) => order.status == OrderStatus.unpaid)
        .length;
    final actual = TextEditingController(text: expected.toStringAsFixed(2));
    final confirmed = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('تقفيل شيفت ${shift.cashierName}'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ListRow(
                title: 'كاش بداية الشيفت',
                trailing: (shift.openingCash ?? 0).toStringAsFixed(2),
              ),
              _ListRow(
                title: 'الكاش المتوقع',
                trailing: expected.toStringAsFixed(2),
              ),
              if (unpaid > 0)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFFFFF7ED),
                  child: Text(
                    'تنبيه: يوجد $unpaid طلب صالة غير مدفوع في هذا الشيفت.',
                    style: const TextStyle(
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              TextField(
                controller: actual,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكاش الفعلي بعد العد',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = double.tryParse(actual.text.trim());
              if (value != null && value >= 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            icon: const Icon(Icons.lock_outline),
            label: const Text('تقفيل'),
          ),
        ],
      ),
    );
    if (confirmed == null) return;
    await widget.onClose(shift, confirmed);
  }

  Future<void> _addCashMovement(Shift shift) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var type = CashDrawerTransactionType.expense;
    final result =
        await showDialog<(CashDrawerTransactionType, double, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('حركة درج نقدي'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CashDrawerTransactionType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'نوع الحركة'),
                  items: const [
                    DropdownMenuItem(
                      value: CashDrawerTransactionType.expense,
                      child: Text('مصروف'),
                    ),
                    DropdownMenuItem(
                      value: CashDrawerTransactionType.cashIn,
                      child: Text('إيداع نقدي'),
                    ),
                    DropdownMenuItem(
                      value: CashDrawerTransactionType.cashOut,
                      child: Text('سحب نقدي'),
                    ),
                    DropdownMenuItem(
                      value: CashDrawerTransactionType.supplierPayment,
                      child: Text('دفع مورد'),
                    ),
                    DropdownMenuItem(
                      value: CashDrawerTransactionType.purchasePayment,
                      child: Text('دفع مشتريات'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'البيان'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amount.text.trim());
                if (value == null || value <= 0) return;
                Navigator.of(dialogContext)
                    .pop((type, value, note.text.trim()));
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final dependencies = AppStateScope.of(context);
    final user = await dependencies.authRepository.currentUser();
    final isIncoming = result.$1 == CashDrawerTransactionType.cashIn;
    final transaction = CashDrawerTransaction(
      id: 'cash-${DateTime.now().microsecondsSinceEpoch}',
      type: result.$1,
      amount: isIncoming ? result.$2 : -result.$2,
      shiftId: shift.id,
      noteAr: result.$3.isEmpty ? null : result.$3,
      createdBy: user?.id ?? 'manager',
      createdAt: DateTime.now(),
    );
    await dependencies.cashRepository.saveTransaction(transaction);
    await widget.onLog('cash_drawer_transaction', result.$3);
    widget.onChanged();
  }

  Future<void> _setArchived(Shift shift, bool archived) async {
    await AppStateScope.of(context).shiftRepository.saveShift(
          shift.copyWith(
            archived: archived,
            updatedAt: DateTime.now(),
          ),
        );
    await widget.onLog(
      archived ? 'shift_archived' : 'shift_unarchived',
      shift.cashierName,
    );
    setState(() => _selected = null);
    widget.onChanged();
  }

  Future<void> _printShift(Shift shift) async {
    final orders = _ordersForShift(shift);
    final paid = orders.where((order) => order.status == OrderStatus.paid);
    final revenue = paid.fold<double>(
      0,
      (sum, order) => sum + order.totals.total,
    );
    final cash = paid.fold<double>(
      0,
      (sum, order) => sum + (order.cashPaid ?? 0),
    );
    final card = paid.fold<double>(
      0,
      (sum, order) => sum + (order.cardPaid ?? 0),
    );
    final settings =
        await AppStateScope.of(context).settingsRepository.getPosSettings();
    final result = await const PlatformPrintService().printText(
      [
        settings.restaurantNameAr,
        'SHIFT SUMMARY',
        'Cashier: ${shift.cashierName}',
        'Opened: ${shift.openedAt}',
        if (shift.closedAt != null) 'Closed: ${shift.closedAt}',
        'Orders: ${orders.length}',
        'Paid: ${paid.length}',
        'Revenue: ${revenue.toStringAsFixed(2)} ${settings.currencySymbol}',
        'Cash: ${cash.toStringAsFixed(2)}',
        'Card: ${card.toStringAsFixed(2)}',
        'Opening cash: ${(shift.openingCash ?? 0).toStringAsFixed(2)}',
        'Expected cash: ${_expectedCash(shift).toStringAsFixed(2)}',
        if (shift.closingCash != null)
          'Closing cash: ${shift.closingCash!.toStringAsFixed(2)}',
      ].join('\r\n'),
      printerName: settings.defaultReceiptPrinter,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.ok ? 'Shift summary sent to printer.' : result.error!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleShifts = widget.shifts
        .where((shift) => shift.archived == _showArchived)
        .toList();
    final paidSales = widget.orders
        .where((order) => order.status == OrderStatus.paid)
        .fold<double>(0, (sum, order) => sum + order.totals.total);
    return _PageScaffold(
      title: 'الشيفتات',
      subtitle: 'مراجعة وتقفيل وأرشفة',
      child: ListView(
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(
                  'الشيفتات النشطة (${widget.shifts.where((shift) => !shift.archived).length})',
                ),
              ),
              ButtonSegment(
                value: true,
                label: Text(
                  'المؤرشفة (${widget.shifts.where((shift) => shift.archived).length})',
                ),
              ),
            ],
            selected: {_showArchived},
            onSelectionChanged: (selection) => setState(() {
              _showArchived = selection.first;
              _selected = null;
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'الشيفتات',
                value: visibleShifts.length.toString(),
              ),
              _MetricCard(
                  title: 'مبيعات مدفوعة', value: paidSales.toStringAsFixed(2)),
              _MetricCard(
                  title: 'طلبات غير مدفوعة',
                  value: widget.orders
                      .where((order) => order.isUnpaidDineIn)
                      .length
                      .toString()),
            ],
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'سجل الشيفتات',
            child: Column(
              children: visibleShifts
                  .map(
                    (shift) => _ListRow(
                      title:
                          '${shift.cashierName} - ${_shiftStatusLabel(shift.status)}',
                      subtitle:
                          'افتتاح ${(shift.openingCash ?? 0).toStringAsFixed(2)} • ${_formatDateTime(shift.openedAt)}',
                      trailingWidget: Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: () => setState(() => _selected = shift),
                            child: const Text('عرض'),
                          ),
                          if (shift.status == ShiftStatus.open &&
                              !_showArchived)
                            OutlinedButton.icon(
                              onPressed: () => _addCashMovement(shift),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('حركة درج'),
                            ),
                          if (shift.status == ShiftStatus.open &&
                              !_showArchived)
                            FilledButton(
                              onPressed: () => _closeShift(shift),
                              child: const Text('تقفيل'),
                            ),
                          if (shift.status == ShiftStatus.closed)
                            OutlinedButton(
                              onPressed: () =>
                                  _setArchived(shift, !_showArchived),
                              child: Text(
                                _showArchived ? 'إلغاء الأرشفة' : 'أرشفة',
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 14),
            _buildSummary(_selected!),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(Shift shift) {
    final orders = _ordersForShift(shift);
    final completed =
        orders.where((order) => order.status == OrderStatus.paid).toList();
    final cancelled =
        orders.where((order) => order.status == OrderStatus.cancelled).toList();
    final revenue =
        completed.fold<double>(0, (sum, order) => sum + order.totals.total);
    final cashRevenue = completed.fold<double>(
      0,
      (sum, order) => sum + (order.cashPaid ?? 0),
    );
    final cardRevenue = completed.fold<double>(
      0,
      (sum, order) => sum + (order.cardPaid ?? 0),
    );
    final cashTransactions = _cashForShift(shift);
    final cashMovements = cashTransactions
        .where(
            (transaction) => transaction.type != CashDrawerTransactionType.sale)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final expenses = cashTransactions
        .where((transaction) => transaction.amount < 0)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount.abs());
    final drawerTotal = cashRevenue + cashMovements;
    final expectedCash = (shift.openingCash ?? 0) + drawerTotal;
    final actualCash = shift.closingCash;
    final orderIds = orders.map((order) => order.id).toSet();
    final inventory = _inventoryForShift(shift, orderIds);
    final itemSummary = <String, (String, double, double)>{};
    for (final order in completed) {
      for (final line in order.lines) {
        final key = '${line.nameAr}|${line.sizeLabelAr ?? ''}';
        final current = itemSummary[key];
        itemSummary[key] = (
          line.sizeLabelAr == null
              ? line.nameAr
              : '${line.nameAr} - ${line.sizeLabelAr}',
          (current?.$2 ?? 0) + line.quantity,
          (current?.$3 ?? 0) + line.total,
        );
      }
    }
    final typeCounts = {
      for (final type in OrderType.values)
        type: completed.where((order) => order.type == type).length,
    };
    return _DataPanel(
      trailing: IconButton(
        tooltip: 'Print shift summary',
        onPressed: () => _printShift(shift),
        icon: const Icon(Icons.print_outlined),
      ),
      title: 'ملخص شيفت ${shift.cashierName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'إجمالي الإيراد',
                value: revenue.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'إيراد نقدي',
                value: cashRevenue.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'إيراد بطاقة',
                value: cardRevenue.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'فلوس الدرج',
                value: drawerTotal.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'المصروفات',
                value: expenses.toStringAsFixed(2),
              ),
              _MetricCard(title: 'كل الطلبات', value: orders.length.toString()),
              _MetricCard(
                title: 'طلبات مكتملة',
                value: completed.length.toString(),
              ),
              _MetricCard(
                title: 'طلبات ملغية',
                value: cancelled.length.toString(),
              ),
              _MetricCard(
                title: 'الكاش المتوقع',
                value: expectedCash.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'طلبات الصالة',
                value: '${typeCounts[OrderType.dineIn]}',
              ),
              _MetricCard(
                title: 'طلبات الدليفري',
                value: '${typeCounts[OrderType.delivery]}',
              ),
              _MetricCard(
                title: 'طلبات التيك أواي',
                value: '${typeCounts[OrderType.takeaway]}',
              ),
              if (actualCash != null)
                _MetricCard(
                  title: 'الكاش الفعلي',
                  value: actualCash.toStringAsFixed(2),
                ),
              if (actualCash != null)
                _MetricCard(
                  title: 'فرق الكاش',
                  value: (actualCash - expectedCash).toStringAsFixed(2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _OrdersTable(orders: orders),
          const SizedBox(height: 16),
          const Text(
            'الأصناف المباعة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _SimpleTable(
            columns: const ['الصنف', 'الكمية', 'الإجمالي'],
            rows: itemSummary.values
                .map((item) => [
                      item.$1,
                      item.$2.toStringAsFixed(
                        item.$2 == item.$2.roundToDouble() ? 0 : 3,
                      ),
                      item.$3.toStringAsFixed(2),
                    ])
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'حركات الدرج',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _SimpleTable(
            columns: const ['النوع', 'المبلغ', 'البيان', 'الوقت'],
            rows: cashTransactions
                .map((transaction) => [
                      _cashTransactionLabel(transaction.type),
                      transaction.amount.toStringAsFixed(2),
                      transaction.noteAr ?? '-',
                      _formatDateTime(transaction.createdAt),
                    ])
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'حركات المخزون',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _SimpleTable(
            columns: const ['المكون', 'الحركة', 'الكمية', 'الوحدة'],
            rows: inventory
                .map((transaction) => [
                      transaction.ingredientNameAr ?? transaction.ingredientId,
                      _inventoryTypeLabel(transaction.type),
                      transaction.quantityDelta.toStringAsFixed(3),
                      transaction.unit,
                    ])
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SuppliersSection extends StatefulWidget {
  const _SuppliersSection({
    required this.suppliers,
    required this.transactions,
    required this.onAdd,
    required this.onChanged,
    required this.onLog,
  });

  final List<Supplier> suppliers;
  final List<SupplierTransaction> transactions;
  final Future<void> Function(Supplier supplier) onAdd;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<_SuppliersSection> createState() => _SuppliersSectionState();
}

class _SuppliersSectionState extends State<_SuppliersSection> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _txAmount = TextEditingController();
  final _txNote = TextEditingController();
  String? _txSupplierId;
  SupplierTransactionType _txType = SupplierTransactionType.payment;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _txAmount.dispose();
    _txNote.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final now = DateTime.now();
    await widget.onAdd(
      Supplier(
        id: 'supplier-${now.microsecondsSinceEpoch}',
        nameAr: _name.text.trim(),
        phone: _phone.text.trim(),
        noteAr: _note.text.trim().isEmpty ? null : _note.text.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    _name.clear();
    _phone.clear();
    _note.clear();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _submitTransaction() async {
    final supplierId = _txSupplierId;
    final amount = (double.tryParse(_txAmount.text) ?? 0).abs();
    if (supplierId == null || amount <= 0 || _submitting) return;
    setState(() => _submitting = true);
    final signedAmount = switch (_txType) {
      SupplierTransactionType.payment ||
      SupplierTransactionType.debtDecrease ||
      SupplierTransactionType.settlement =>
        -amount,
      SupplierTransactionType.purchaseDebtIncrease ||
      SupplierTransactionType.adjustment =>
        amount,
    };
    final transaction = SupplierTransaction(
      id: 'supplier-tx-${DateTime.now().microsecondsSinceEpoch}',
      supplierId: supplierId,
      amountDelta: signedAmount,
      type: _txType,
      createdAt: DateTime.now(),
      noteAr: _txNote.text.trim().isEmpty ? null : _txNote.text.trim(),
      createdBy: 'manager',
    );
    await AppStateScope.of(context)
        .supplierRepository
        .saveTransaction(transaction);
    await widget.onLog('supplier_transaction', supplierId);
    _txAmount.clear();
    _txNote.clear();
    widget.onChanged();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _toggleSupplier(Supplier supplier) async {
    await AppStateScope.of(context).supplierRepository.saveSupplier(
          supplier.copyWith(
            active: !supplier.active,
            updatedAt: DateTime.now(),
          ),
        );
    await widget.onLog('supplier_active_changed', supplier.nameAr);
    widget.onChanged();
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    await AppStateScope.of(context)
        .supplierRepository
        .deleteSupplier(supplier.id);
    await widget.onLog('supplier_deleted', supplier.nameAr);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final balances = <String, double>{};
    for (final transaction in widget.transactions) {
      balances.update(
        transaction.supplierId,
        (value) => value + transaction.amountDelta,
        ifAbsent: () => transaction.amountDelta,
      );
    }
    final supplierNames = {
      for (final supplier in widget.suppliers) supplier.id: supplier.nameAr,
    };
    return _PageScaffold(
      title: 'الموردين',
      subtitle: 'حسابات وتوريدات الموردين',
      child: ListView(
        children: [
          _DataPanel(
            title: 'إضافة مورد',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SmallField(controller: _name, label: 'اسم المورد'),
                _SmallField(controller: _phone, label: 'الهاتف'),
                _SmallField(controller: _note, label: 'ملاحظات', width: 220),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.add_business),
                  label: const Text('إضافة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'حركة حساب مورد',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    initialValue: _txSupplierId,
                    decoration: const InputDecoration(labelText: 'المورد'),
                    items: widget.suppliers
                        .where((supplier) => supplier.active)
                        .map(
                          (supplier) => DropdownMenuItem(
                            value: supplier.id,
                            child: Text(supplier.nameAr),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _txSupplierId = value),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<SupplierTransactionType>(
                    initialValue: _txType,
                    decoration: const InputDecoration(labelText: 'نوع الحركة'),
                    items: SupplierTransactionType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(_supplierTransactionLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _txType = value ?? SupplierTransactionType.payment,
                    ),
                  ),
                ),
                _SmallField(
                  controller: _txAmount,
                  label: 'المبلغ',
                  width: 140,
                ),
                _SmallField(
                  controller: _txNote,
                  label: 'السبب / الملاحظة',
                  width: 220,
                ),
                FilledButton(
                  onPressed: _submitting ? null : _submitTransaction,
                  child: const Text('تسجيل الحركة'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'الموردين',
            child: Column(
              children: widget.suppliers
                  .map(
                    (supplier) => _ListRow(
                      title: supplier.nameAr,
                      subtitle:
                          '${supplier.phone ?? '-'} • الرصيد ${(balances[supplier.id] ?? 0).toStringAsFixed(2)}',
                      trailingWidget: Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: () => _toggleSupplier(supplier),
                            child: Text(supplier.active ? 'مفعل' : 'معطل'),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _deleteSupplier(supplier),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'سجل عمليات التوريد',
            child: _SimpleTable(
              columns: const [
                'الوقت',
                'المورد',
                'نوع الحركة',
                'المبلغ',
                'ملاحظة',
              ],
              rows: widget.transactions
                  .map(
                    (transaction) => [
                      _formatDateTime(transaction.createdAt),
                      supplierNames[transaction.supplierId] ??
                          transaction.supplierId,
                      _supplierTransactionLabel(transaction.type),
                      transaction.amountDelta.abs().toStringAsFixed(2),
                      transaction.noteAr ?? '-',
                    ],
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashierHistorySection extends StatefulWidget {
  const _CashierHistorySection({
    required this.orders,
    required this.onChanged,
    required this.onLog,
  });

  final List<Order> orders;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<_CashierHistorySection> createState() => _CashierHistorySectionState();
}

class _CashierHistorySectionState extends State<_CashierHistorySection> {
  OrderStatus? _status;
  OrderType? _type;
  String? _cashier;

  Future<void> _cancelOrder(Order order) async {
    await AppStateScope.of(context).orderRepository.save(order.cancel());
    await widget.onLog('order_cancelled', '#${order.orderNumber}');
    widget.onChanged();
  }

  Future<void> _showReceipt(Order order) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('فاتورة #${order.orderNumber}'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in order.lines)
                  _ListRow(
                    title: line.nameAr,
                    subtitle:
                        '${line.quantity.toStringAsFixed(2)} × ${line.unitPrice.toStringAsFixed(2)}',
                    trailing: line.total.toStringAsFixed(2),
                  ),
                const Divider(),
                _ListRow(
                  title: 'الإجمالي',
                  trailing: order.totals.total.toStringAsFixed(2),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(Order order) async {
    final dependencies = AppStateScope.of(context);
    final settings = await dependencies.settingsRepository.getPosSettings();
    final receipt = const ReceiptTextBuilder().build(order, settings);
    final result = await const PlatformPrintService().printText(
      receipt,
      printerName: settings.defaultReceiptPrinter,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'Receipt sent to printer.' : result.error!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashiers = widget.orders
        .map((order) => order.cashierName)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final orders = widget.orders.where((order) {
      return (_status == null || order.status == _status) &&
          (_type == null || order.type == _type) &&
          (_cashier == null || order.cashierName == _cashier);
    }).toList();
    return _PageScaffold(
      title: 'سجل الكاشيرات',
      subtitle: 'أوردرات الكاشير اليومية',
      child: ListView(
        children: [
          _DataPanel(
            title: 'الفلاتر',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<OrderStatus?>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: [
                      const DropdownMenuItem<OrderStatus?>(
                        child: Text('كل الحالات'),
                      ),
                      ...OrderStatus.values.map(
                        (status) => DropdownMenuItem<OrderStatus?>(
                          value: status,
                          child: Text(_orderStatusLabel(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _status = value),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<OrderType?>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'النوع'),
                    items: [
                      const DropdownMenuItem<OrderType?>(
                        child: Text('كل الأنواع'),
                      ),
                      ...OrderType.values.map(
                        (type) => DropdownMenuItem<OrderType?>(
                          value: type,
                          child: Text(_orderTypeLabel(type)),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _type = value),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _cashier,
                    decoration: const InputDecoration(labelText: 'الكاشير'),
                    items: [
                      const DropdownMenuItem<String?>(
                        child: Text('كل الكاشيرات'),
                      ),
                      ...cashiers.map(
                        (cashier) => DropdownMenuItem<String?>(
                          value: cashier,
                          child: Text(cashier),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _cashier = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DataPanel(
            title: 'الطلبات (${orders.length})',
            child: Column(
              children: orders
                  .map(
                    (order) => _ListRow(
                      title:
                          '#${order.orderNumber} • ${order.cashierName ?? 'غير محدد'}',
                      subtitle:
                          '${_orderTypeLabel(order.type)} • ${_orderStatusLabel(order.status)} • ${_formatDateTime(order.createdAt)}',
                      trailingWidget: Wrap(
                        spacing: 6,
                        children: [
                          OutlinedButton(
                            onPressed: () => _showReceipt(order),
                            child: const Text('عرض / نسخة'),
                          ),
                          IconButton(
                            tooltip: 'Print receipt',
                            onPressed: () => _printReceipt(order),
                            icon: const Icon(Icons.print_outlined),
                          ),
                          if (order.status != OrderStatus.cancelled)
                            IconButton(
                              tooltip: 'إلغاء الطلب',
                              onPressed: () => _cancelOrder(order),
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsSection extends StatefulWidget {
  const _ReportsSection({
    required this.snapshot,
  });

  final _ManagerSnapshot snapshot;

  @override
  State<_ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<_ReportsSection> {
  _ReportRange _range = _ReportRange.month;
  _ReportTab _tab = _ReportTab.daily;

  Future<void> _exportCsv(List<Order> orders) async {
    final report = _reportData(orders);
    final outputDirectory = Directory(
      path.join(
        (await getApplicationDocumentsDirectory()).path,
        'SHIFT POS Reports',
      ),
    );
    await outputDirectory.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final output = File(
      path.join(outputDirectory.path, 'shift-report-${_tab.name}-$stamp.csv'),
    );
    final csv = [report.columns, ...report.rows]
        .map((row) => row.map(_escapeCsv).join(','))
        .join('\r\n');
    await output.writeAsString('\uFEFF$csv', encoding: utf8);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report saved: ${output.path}')),
    );
  }

  Future<void> _printReport(List<Order> orders) async {
    final report = _reportData(orders);
    final lines = <String>[
      'SHIFT POS - ${_tab.name.toUpperCase()} REPORT',
      'Range: ${_range.name}',
      'Generated: ${DateTime.now()}',
      '',
      report.columns.join(' | '),
      ...report.rows.map((row) => row.join(' | ')),
    ];
    final result = await const PlatformPrintService().printText(
      lines.join('\r\n'),
      printerName: widget.snapshot.settings.defaultReportPrinter,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.ok ? 'Report sent to printer.' : result.error!),
      ),
    );
  }

  String _escapeCsv(String value) =>
      '"${value.replaceAll('"', '""').replaceAll('\r', ' ').replaceAll('\n', ' ')}"';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _range.start(now);
    final paidOrders = widget.snapshot.orders
        .where(
          (order) =>
              order.status == OrderStatus.paid &&
              (start == null || !order.createdAt.isBefore(start)),
        )
        .toList();
    final revenue =
        paidOrders.fold<double>(0, (sum, order) => sum + order.totals.total);
    final average = paidOrders.isEmpty ? 0 : revenue / paidOrders.length;
    final todayOrders =
        paidOrders.where((order) => _sameDay(order.createdAt, now)).toList();
    final weekStart = now.subtract(const Duration(days: 7));
    final weekRevenue = widget.snapshot.orders
        .where(
          (order) =>
              order.status == OrderStatus.paid &&
              !order.createdAt.isBefore(weekStart),
        )
        .fold<double>(0, (sum, order) => sum + order.totals.total);
    return _PageScaffold(
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: paidOrders.isEmpty ? null : () => _exportCsv(paidOrders),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('CSV'),
          ),
          OutlinedButton.icon(
            onPressed:
                paidOrders.isEmpty ? null : () => _printReport(paidOrders),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
        ],
      ),
      title: 'التقارير',
      subtitle: 'إيرادات وملخصات',
      child: ListView(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _ReportRange.values
                .map(
                  (range) => ChoiceChip(
                    selected: _range == range,
                    label: Text(range.label),
                    onSelected: (_) => setState(() => _range = range),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricCard(
                title: 'إجمالي الطلبات - ${_range.label}',
                value: paidOrders.length.toString(),
              ),
              _MetricCard(
                title: 'إجمالي الإيرادات',
                value:
                    '${revenue.toStringAsFixed(2)} ${widget.snapshot.settings.currencySymbol}',
              ),
              _MetricCard(
                title: 'متوسط قيمة الطلب',
                value: average.toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'طلبات اليوم',
                value: todayOrders.length.toString(),
              ),
              _MetricCard(
                title: 'إيرادات اليوم',
                value: todayOrders
                    .fold<double>(
                      0,
                      (sum, order) => sum + order.totals.total,
                    )
                    .toStringAsFixed(2),
              ),
              _MetricCard(
                title: 'إيرادات آخر ٧ أيام',
                value: weekRevenue.toStringAsFixed(2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<_ReportTab>(
            segments: const [
              ButtonSegment(
                value: _ReportTab.daily,
                label: Text('المبيعات اليومية'),
              ),
              ButtonSegment(
                value: _ReportTab.items,
                label: Text('أكثر الأصناف مبيعاً'),
              ),
              ButtonSegment(
                value: _ReportTab.cashiers,
                label: Text('أداء الكاشيرات'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) =>
                setState(() => _tab = selection.first),
          ),
          const SizedBox(height: 12),
          _DataPanel(
            title: _tab.label,
            child: switch (_tab) {
              _ReportTab.daily => _dailyReport(paidOrders),
              _ReportTab.items => _itemsReport(paidOrders),
              _ReportTab.cashiers => _cashiersReport(paidOrders),
            },
          ),
        ],
      ),
    );
  }

  Widget _dailyReport(List<Order> orders) {
    final rows = <String, List<Order>>{};
    for (final order in orders) {
      final key = _dateKey(order.createdAt);
      rows.putIfAbsent(key, () => []).add(order);
    }
    final keys = rows.keys.toList()..sort((a, b) => b.compareTo(a));
    return _SimpleTable(
      columns: const [
        'التاريخ',
        'عدد الطلبات',
        'إجمالي المبيعات',
        'متوسط الطلب',
      ],
      rows: keys.map((key) {
        final dayOrders = rows[key]!;
        final total = dayOrders.fold<double>(
          0,
          (sum, order) => sum + order.totals.total,
        );
        return [
          key,
          dayOrders.length.toString(),
          total.toStringAsFixed(2),
          (total / dayOrders.length).toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  Widget _itemsReport(List<Order> orders) {
    final quantities = <String, double>{};
    final revenues = <String, double>{};
    for (final order in orders) {
      for (final line in order.lines) {
        quantities.update(
          line.nameAr,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
        revenues.update(
          line.nameAr,
          (value) => value + line.total,
          ifAbsent: () => line.total,
        );
      }
    }
    final names = quantities.keys.toList()
      ..sort((a, b) => quantities[b]!.compareTo(quantities[a]!));
    return _SimpleTable(
      columns: const ['#', 'الصنف', 'الكمية المباعة', 'الإيراد'],
      rows: names
          .asMap()
          .entries
          .map(
            (entry) => [
              '${entry.key + 1}',
              entry.value,
              quantities[entry.value]!.toStringAsFixed(2),
              revenues[entry.value]!.toStringAsFixed(2),
            ],
          )
          .toList(),
    );
  }

  Widget _cashiersReport(List<Order> orders) {
    final grouped = <String, List<Order>>{};
    for (final order in orders) {
      final cashier = order.cashierName ?? 'غير محدد';
      grouped.putIfAbsent(cashier, () => []).add(order);
    }
    return _SimpleTable(
      columns: const [
        'الكاشير',
        'عدد الطلبات',
        'إجمالي المبيعات',
        'متوسط الطلب',
      ],
      rows: grouped.entries.map((entry) {
        final total = entry.value.fold<double>(
          0,
          (sum, order) => sum + order.totals.total,
        );
        return [
          entry.key,
          entry.value.length.toString(),
          total.toStringAsFixed(2),
          (total / entry.value.length).toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  _ReportData _reportData(List<Order> orders) {
    return switch (_tab) {
      _ReportTab.daily => _dailyReportData(orders),
      _ReportTab.items => _itemsReportData(orders),
      _ReportTab.cashiers => _cashiersReportData(orders),
    };
  }

  _ReportData _dailyReportData(List<Order> orders) {
    final grouped = <String, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(_dateKey(order.createdAt), () => []).add(order);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return _ReportData(
      const ['Date', 'Orders', 'Revenue', 'Average'],
      keys.map((key) {
        final dayOrders = grouped[key]!;
        final total = dayOrders.fold<double>(
          0,
          (sum, order) => sum + order.totals.total,
        );
        return [
          key,
          '${dayOrders.length}',
          total.toStringAsFixed(2),
          (total / dayOrders.length).toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  _ReportData _itemsReportData(List<Order> orders) {
    final quantities = <String, double>{};
    final revenues = <String, double>{};
    for (final order in orders) {
      for (final line in order.lines) {
        quantities.update(
          line.nameAr,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
        revenues.update(
          line.nameAr,
          (value) => value + line.total,
          ifAbsent: () => line.total,
        );
      }
    }
    final names = quantities.keys.toList()
      ..sort((a, b) => quantities[b]!.compareTo(quantities[a]!));
    return _ReportData(
      const ['Rank', 'Item', 'Quantity', 'Revenue'],
      names.asMap().entries.map((entry) {
        final name = entry.value;
        return [
          '${entry.key + 1}',
          name,
          quantities[name]!.toStringAsFixed(2),
          revenues[name]!.toStringAsFixed(2),
        ];
      }).toList(),
    );
  }

  _ReportData _cashiersReportData(List<Order> orders) {
    final grouped = <String, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(order.cashierName ?? 'Unknown', () => []).add(order);
    }
    return _ReportData(
      const ['Cashier', 'Orders', 'Revenue', 'Average'],
      grouped.entries.map((entry) {
        final total = entry.value.fold<double>(
          0,
          (sum, order) => sum + order.totals.total,
        );
        return [
          entry.key,
          '${entry.value.length}',
          total.toStringAsFixed(2),
          (total / entry.value.length).toStringAsFixed(2),
        ];
      }).toList(),
    );
  }
}

class _ReportData {
  const _ReportData(this.columns, this.rows);

  final List<String> columns;
  final List<List<String>> rows;
}

enum _ReportTab {
  daily('المبيعات اليومية'),
  items('أكثر الأصناف مبيعاً'),
  cashiers('أداء الكاشيرات');

  const _ReportTab(this.label);
  final String label;
}

enum _ReportRange {
  today('اليوم'),
  week('آخر ٧ أيام'),
  month('آخر ٣٠ يوم'),
  year('آخر سنة'),
  all('كل السجل');

  const _ReportRange(this.label);
  final String label;

  DateTime? start(DateTime now) {
    return switch (this) {
      _ReportRange.today => DateTime(now.year, now.month, now.day),
      _ReportRange.week => now.subtract(const Duration(days: 7)),
      _ReportRange.month => now.subtract(const Duration(days: 30)),
      _ReportRange.year => DateTime(now.year - 1, now.month, now.day),
      _ReportRange.all => null,
    };
  }
}

class _AuditSection extends StatefulWidget {
  const _AuditSection({required this.audit});

  final List<AuditEvent> audit;

  @override
  State<_AuditSection> createState() => _AuditSectionState();
}

class _AuditSectionState extends State<_AuditSection> {
  final _search = TextEditingController();
  String? _action;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = widget.audit.map((event) => event.action).toSet().toList()
      ..sort();
    final query = _search.text.trim().toLowerCase();
    final events = widget.audit.where((event) {
      final text =
          '${event.actorUsername} ${event.action} ${event.detailAr ?? ''}'
              .toLowerCase();
      return (_action == null || event.action == _action) &&
          (query.isEmpty || text.contains(query));
    }).toList();
    return _PageScaffold(
      title: 'سجل الأحداث',
      subtitle: 'مراقبة وتدقيق العمليات',
      child: ListView(
        children: [
          _DataPanel(
            title: 'الفلاتر',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'بحث في المستخدم أو التفاصيل',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _action,
                    decoration: const InputDecoration(labelText: 'الإجراء'),
                    items: [
                      const DropdownMenuItem<String?>(
                        child: Text('كل الإجراءات'),
                      ),
                      ...actions.map(
                        (action) => DropdownMenuItem<String?>(
                          value: action,
                          child: Text(action),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _action = value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DataPanel(
            title: 'الأحداث (${events.length})',
            child: Column(
              children: events
                  .map(
                    (event) => _ListRow(
                      title: event.action,
                      subtitle:
                          '${event.actorUsername} • ${_formatDateTime(event.createdAt)}\n${event.detailAr ?? ''}',
                      trailingWidget: IconButton(
                        tooltip: 'التفاصيل',
                        onPressed: () => _showDetails(event),
                        icon: const Icon(Icons.info_outline),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(AuditEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(event.action),
        content: SelectionArea(
          child: Text(
            [
              'المستخدم: ${event.actorUsername}',
              'الوقت: ${_formatDateTime(event.createdAt)}',
              if (event.targetType != null) 'النوع: ${event.targetType}',
              if (event.targetId != null) 'المعرّف: ${event.targetId}',
              if (event.detailAr != null) 'التفاصيل: ${event.detailAr}',
              if (event.metadata.isNotEmpty) 'البيانات: ${event.metadata}',
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}

class _DefaultPrinterPanel extends StatefulWidget {
  const _DefaultPrinterPanel({
    required this.settings,
    required this.onChanged,
    required this.onLog,
  });

  final PosSettings settings;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  @override
  State<_DefaultPrinterPanel> createState() => _DefaultPrinterPanelState();
}

class _DefaultPrinterPanelState extends State<_DefaultPrinterPanel> {
  List<SystemPrinter> _printers = const [];
  String _receipt = '';
  String _report = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _receipt = widget.settings.defaultReceiptPrinter ?? '';
    _report = widget.settings.defaultReportPrinter ?? '';
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final printers =
        await AppStateScope.of(context).printerRepository.listSystemPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final dependencies = AppStateScope.of(context);
    final settings = widget.settings.copyWith(
      defaultReceiptPrinter: _receipt,
      defaultReportPrinter: _report,
    );
    await dependencies.settingsRepository.savePosSettings(settings);
    dependencies.settingsNotifier.value = settings;
    await widget.onLog(
        'default_printers_updated', 'receipt=$_receipt report=$_report');
    widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default printers saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = <String>{
      '',
      ..._printers.map((printer) => printer.name),
      if (_receipt.isNotEmpty) _receipt,
      if (_report.isNotEmpty) _report,
    };
    return _DataPanel(
      title: 'Default device printers',
      trailing: _loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Refresh printer list',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              initialValue: _receipt,
              decoration: const InputDecoration(labelText: 'Receipt printer'),
              items: names
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name.isEmpty ? 'System default' : name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _receipt = value ?? ''),
            ),
          ),
          SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              initialValue: _report,
              decoration: const InputDecoration(labelText: 'Report printer'),
              items: names
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name.isEmpty ? 'System default' : name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _report = value ?? ''),
            ),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PrinterSettingsPanel extends StatelessWidget {
  const _PrinterSettingsPanel({
    required this.printers,
    required this.onChanged,
    required this.onLog,
  });

  final List<KitchenPrinter> printers;
  final VoidCallback onChanged;
  final Future<void> Function(String action, String details) onLog;

  Future<void> _edit(BuildContext context, [KitchenPrinter? printer]) async {
    final repository = AppStateScope.of(context).printerRepository;
    final systemPrinters = await repository.listSystemPrinters();
    if (!context.mounted) return;
    final name = TextEditingController(text: printer?.name ?? '');
    final device = TextEditingController(text: printer?.deviceName ?? '');
    final description = TextEditingController(text: printer?.description ?? '');
    final copies = TextEditingController(text: '${printer?.copies ?? 1}');
    var active = printer?.active ?? true;
    var visibility = printer?.visibility ?? const KitchenPrinterVisibility();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(printer == null ? 'إضافة طابعة تجهيز' : 'تعديل الطابعة'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'اسم الطابعة'),
                  ),
                  const SizedBox(height: 8),
                  if (systemPrinters.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: systemPrinters
                              .any((value) => value.name == device.text)
                          ? device.text
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'طابعة النظام'),
                      items: systemPrinters
                          .map((value) => DropdownMenuItem(
                                value: value.name,
                                child: Text(value.displayName),
                              ))
                          .toList(),
                      onChanged: (value) => device.text = value ?? device.text,
                    ),
                  if (systemPrinters.isNotEmpty) const SizedBox(height: 8),
                  TextField(
                    controller: device,
                    decoration: const InputDecoration(
                      labelText: 'اسم جهاز الطباعة',
                      helperText: 'يمكن إدخاله يدوياً على Android أو الشبكة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'الوصف'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: copies,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد النسخ'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    title: const Text('الطابعة مفعلة'),
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                  const Divider(),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'بيانات تذكرة المطبخ',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _visibilitySwitch(
                    'نوع الطلب',
                    visibility.showOrderType,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showOrderType: value)),
                  ),
                  _visibilitySwitch(
                    'الترابيزة',
                    visibility.showTable,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showTable: value)),
                  ),
                  _visibilitySwitch(
                    'الكاشير',
                    visibility.showCashier,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showCashier: value)),
                  ),
                  _visibilitySwitch(
                    'العميل',
                    visibility.showCustomer,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showCustomer: value)),
                  ),
                  _visibilitySwitch(
                    'ملاحظة الطلب',
                    visibility.showOrderNote,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showOrderNote: value)),
                  ),
                  _visibilitySwitch(
                    'ملاحظات الأصناف',
                    visibility.showItemNotes,
                    (value) => setDialogState(() =>
                        visibility = visibility.copyWith(showItemNotes: value)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || device.text.trim().isEmpty) {
                  return;
                }
                final now = DateTime.now();
                final saved = await repository.saveKitchenPrinter(
                  KitchenPrinter(
                    id: printer?.id ?? 'printer-${now.microsecondsSinceEpoch}',
                    name: name.text.trim(),
                    deviceName: device.text.trim(),
                    description: description.text.trim().isEmpty
                        ? null
                        : description.text.trim(),
                    copies: (int.tryParse(copies.text) ?? 1).clamp(1, 5),
                    active: active,
                    visibility: visibility,
                    createdAt: printer?.createdAt ?? now,
                    updatedAt: now,
                  ),
                );
                await onLog(
                  printer == null
                      ? 'kitchen_printer_created'
                      : 'kitchen_printer_updated',
                  saved.name,
                );
                onChanged();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visibilitySwitch(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(label),
      onChanged: onChanged,
    );
  }

  Future<void> _delete(BuildContext context, KitchenPrinter printer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف طابعة التجهيز'),
        content: Text('حذف "${printer.name}" من الطابعات ومسارات الأصناف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final dependencies = AppStateScope.of(context);
    await dependencies.printerRepository.deleteKitchenPrinter(printer.id);
    final items =
        await dependencies.menuRepository.listItems(includeInactive: true);
    for (final item in items.where(
      (value) => value.kitchenPrinterIds.contains(printer.id),
    )) {
      await dependencies.menuRepository.saveItem(
        item.copyWith(
          kitchenPrinterIds: item.kitchenPrinterIds
              .where((value) => value != printer.id)
              .toList(),
        ),
      );
    }
    await onLog('kitchen_printer_deleted', printer.name);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: 'طابعات التجهيز',
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('طابعة تجهيز'),
            ),
          ),
          const SizedBox(height: 10),
          if (printers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد طابعات تجهيز.'),
            )
          else
            for (final printer in printers)
              _ListRow(
                title: printer.name,
                subtitle: '${printer.deviceName} • ${printer.copies} نسخة',
                trailingWidget: Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _edit(context, printer),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _delete(context, printer),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _SettingsManagerSection extends StatelessWidget {
  const _SettingsManagerSection({
    required this.settings,
    required this.config,
    required this.kitchenPrinters,
    required this.onLog,
    required this.onChanged,
  });

  final PosSettings settings;
  final AppConfig config;
  final List<KitchenPrinter> kitchenPrinters;
  final Future<void> Function(String action, String details) onLog;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'الإعدادات',
      subtitle: 'اسم المطعم والعملة والتشغيل',
      trailing: Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () =>
                _showPosSettingsDialog(context, settings, onChanged, onLog),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                onLog('طلب إعادة تشغيل', 'زر إعادة التشغيل من Flutter'),
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة التشغيل'),
          ),
        ],
      ),
      child: ListView(
        children: [
          ManagerSettingsPanel(
            settings: settings,
            onChanged: onChanged,
            onLog: onLog,
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'إعدادات نقطة البيع',
            child: Column(
              children: [
                _ListRow(
                    title: 'اسم المطعم', trailing: settings.restaurantNameAr),
                _ListRow(title: 'العملة', trailing: settings.currencySymbol),
                _ListRow(
                    title: 'الضريبة',
                    trailing: '${settings.taxRate.toStringAsFixed(2)}%'),
                _ListRow(
                    title: 'الخدمة',
                    trailing: '${settings.serviceRate.toStringAsFixed(2)}%'),
                _ListRow(
                    title: 'رسوم الدليفري',
                    trailing: settings.deliveryFee.toStringAsFixed(2)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DefaultPrinterPanel(
            settings: settings,
            onChanged: onChanged,
            onLog: onLog,
          ),
          const SizedBox(height: 14),
          _PrinterSettingsPanel(
            printers: kitchenPrinters,
            onChanged: onChanged,
            onLog: onLog,
          ),
          const SizedBox(height: 14),
          _DataPanel(
            title: 'التكوين',
            child: Column(
              children: [
                _ListRow(title: 'البيئة', trailing: config.environment),
                _ListRow(
                    title: 'API',
                    trailing: config.api.enabled ? 'مفعل' : 'معطل'),
                _ListRow(title: 'API endpoint', trailing: config.api.baseUrl),
                _ListRow(
                    title: 'قاعدة البيانات',
                    trailing: config.database.enabled ? 'مفعلة' : 'معطلة'),
                _ListRow(
                    title: 'نوع قاعدة البيانات',
                    trailing: config.database.driver),
                _ListRow(
                    title: 'منفذ الماستر',
                    trailing: config.network.defaultMasterPort.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPosSettingsDialog(
  BuildContext context,
  PosSettings settings,
  VoidCallback onChanged,
  Future<void> Function(String action, String details) onLog,
) async {
  final restaurant = TextEditingController(text: settings.restaurantNameAr);
  final currency = TextEditingController(text: settings.currencySymbol);
  final tax = TextEditingController(text: settings.taxRate.toString());
  final service = TextEditingController(text: settings.serviceRate.toString());
  final delivery = TextEditingController(text: settings.deliveryFee.toString());
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إعدادات نقطة البيع'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: restaurant,
                decoration: const InputDecoration(labelText: 'اسم المطعم'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: currency,
                decoration: const InputDecoration(labelText: 'رمز العملة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tax,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الضريبة %'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: service,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الخدمة %'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: delivery,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'رسوم الدليفري'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () async {
            if (restaurant.text.trim().isEmpty ||
                currency.text.trim().isEmpty) {
              return;
            }
            final next = settings.copyWith(
              restaurantNameAr: restaurant.text.trim(),
              currencySymbol: currency.text.trim(),
              taxRate: double.tryParse(tax.text.trim()) ?? 0,
              serviceRate: double.tryParse(service.text.trim()) ?? 0,
              deliveryFee: double.tryParse(delivery.text.trim()) ?? 0,
            );
            await AppStateScope.of(context)
                .settingsRepository
                .savePosSettings(next);
            await onLog(
              'تعديل الإعدادات',
              'تم تحديث إعدادات المطعم والضرائب والخدمة',
            );
            onChanged();
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
}

class _ManagerSidebar extends StatelessWidget {
  const _ManagerSidebar({
    required this.selected,
    required this.onSelected,
  });

  final _ManagerSection selected;
  final ValueChanged<_ManagerSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(left: BorderSide(color: AppTheme.border, width: 2)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: _ManagerSection.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 5),
        itemBuilder: (context, index) {
          final section = _ManagerSection.values[index];
          final active = selected == section;
          return OutlinedButton.icon(
            onPressed: () => onSelected(section),
            icon: Icon(section.icon, size: 18),
            label: Align(
              alignment: Alignment.centerRight,
              child: Text(section.label, overflow: TextOverflow.ellipsis),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: active ? AppTheme.primary : AppTheme.surface,
              foregroundColor: active ? Colors.white : AppTheme.text,
              side: BorderSide(
                color: active ? AppTheme.primary : AppTheme.border,
                width: 2,
              ),
              alignment: Alignment.centerRight,
            ),
          );
        },
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.muted, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        Expanded(child: child),
      ],
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 184,
      height: 104,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.muted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.sections});

  final List<_ManagerSection> sections;

  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      title: 'أقسام الإدارة',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: sections
            .map(
              (section) => SizedBox(
                width: 180,
                height: 86,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    border: Border.all(color: AppTheme.border, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(section.icon, color: AppTheme.primary),
                        const SizedBox(height: 6),
                        Text(section.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                if (subtitle != null)
                  Text(subtitle!,
                      style:
                          const TextStyle(color: AppTheme.muted, fontSize: 12)),
              ],
            ),
          ),
          trailingWidget ??
              Text(trailing ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text('لا توجد طلبات بعد.', textAlign: TextAlign.center),
      );
    }
    return _SimpleTable(
      columns: const ['رقم', 'النوع', 'الحالة', 'الإجمالي'],
      rows: orders
          .map((order) => [
                '#${order.orderNumber}',
                _orderTypeLabel(order.type),
                _orderStatusLabel(order.status),
                order.totals.total.toStringAsFixed(2),
              ])
          .toList(),
    );
  }
}

class _MenuItemsTable extends StatelessWidget {
  const _MenuItemsTable({
    required this.items,
    required this.categories,
    required this.recipes,
    required this.sizes,
    required this.addons,
    required this.ingredients,
    required this.kitchenPrinters,
    required this.onChanged,
  });

  final List<MenuItem> items;
  final List<MenuCategory> categories;
  final List<Recipe> recipes;
  final List<ItemSize> sizes;
  final List<ItemAddon> addons;
  final List<Ingredient> ingredients;
  final List<KitchenPrinter> kitchenPrinters;
  final VoidCallback onChanged;

  Recipe? _recipeFor(MenuItem item) {
    for (final recipe in recipes) {
      if (recipe.menuItemId == item.id) return recipe;
    }
    return null;
  }

  Future<void> _edit(BuildContext context, MenuItem item) {
    return showMenuItemEditorDialog(
      context,
      categories: categories,
      sizes: sizes,
      addons: addons,
      ingredients: ingredients,
      kitchenPrinters: kitchenPrinters,
      item: item,
      recipe: _recipeFor(item),
      onSaved: () async => onChanged(),
    );
  }

  Future<void> _toggleActive(BuildContext context, MenuItem item) async {
    await AppStateScope.of(context)
        .menuRepository
        .saveItem(item.copyWith(active: !item.active));
    onChanged();
  }

  Future<void> _move(
    BuildContext context,
    MenuItem item,
    int direction,
  ) async {
    final categoryItems = items
        .where((candidate) => candidate.categoryId == item.categoryId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final index =
        categoryItems.indexWhere((candidate) => candidate.id == item.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= categoryItems.length) return;
    final moved = categoryItems.removeAt(index);
    categoryItems.insert(target, moved);
    final repository = AppStateScope.of(context).menuRepository;
    for (var order = 0; order < categoryItems.length; order++) {
      await repository
          .saveItem(categoryItems[order].copyWith(sortOrder: order));
    }
    onChanged();
  }

  Future<void> _delete(BuildContext context, MenuItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الصنف'),
        content: Text('هل تريد حذف "${item.nameAr}" والوصفة المرتبطة به؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppStateScope.of(context).menuRepository.deleteItem(item.id);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = {
      for (final category in categories) category.id: category.nameAr
    };
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text('لا توجد أصناف بعد.', textAlign: TextAlign.center),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.background),
        border: TableBorder.all(color: AppTheme.borderLight),
        columns: const [
          DataColumn(label: Text('ترتيب')),
          DataColumn(label: Text('الصنف')),
          DataColumn(label: Text('التصنيف')),
          DataColumn(label: Text('النوع')),
          DataColumn(label: Text('السعر')),
          DataColumn(label: Text('الحالة')),
          DataColumn(label: Text('إجراءات')),
        ],
        rows: items.map((item) {
          final categoryItems = items
              .where((candidate) => candidate.categoryId == item.categoryId)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final order =
              categoryItems.indexWhere((candidate) => candidate.id == item.id);
          return DataRow(cells: [
            DataCell(Row(children: [
              IconButton(
                tooltip: 'أعلى',
                onPressed: order <= 0 ? null : () => _move(context, item, -1),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                tooltip: 'أسفل',
                onPressed: order >= categoryItems.length - 1
                    ? null
                    : () => _move(context, item, 1),
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
            ])),
            DataCell(Text(item.nameAr)),
            DataCell(Text(categoryNames[item.categoryId] ?? item.categoryId)),
            DataCell(Text(_menuItemTypeLabel(item))),
            DataCell(Text(
              item.isWeighted ? 'ميزان' : item.price.toStringAsFixed(2),
            )),
            DataCell(Text(item.active ? 'مفعل' : 'معطل')),
            DataCell(Row(children: [
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _edit(context, item),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: item.active ? 'تعطيل' : 'تفعيل',
                onPressed: () => _toggleActive(context, item),
                icon: Icon(item.active
                    ? Icons.toggle_on_outlined
                    : Icons.toggle_off_outlined),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => _delete(context, item),
                icon: const Icon(Icons.delete_outline),
              ),
            ])),
          ]);
        }).toList(),
      ),
    );
  }
}

class _SimpleTable extends StatelessWidget {
  const _SimpleTable({
    required this.columns,
    required this.rows,
  });

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text('لا توجد بيانات.', textAlign: TextAlign.center),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppTheme.background),
        border: TableBorder.all(color: AppTheme.borderLight),
        columns:
            columns.map((column) => DataColumn(label: Text(column))).toList(),
        rows: rows
            .map(
              (row) => DataRow(
                cells: [
                  for (final value in row) DataCell(Text(value)),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({
    required this.controller,
    required this.label,
    this.width = 180,
  });

  final TextEditingController controller;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _ManagerSnapshot {
  const _ManagerSnapshot({
    required this.dashboard,
    required this.categories,
    required this.items,
    required this.sizes,
    required this.addons,
    required this.recipes,
    required this.tables,
    required this.orders,
    required this.settings,
    required this.currentUser,
    required this.accounts,
    required this.ingredients,
    required this.ingredientStocks,
    required this.inventoryTransactions,
    required this.suppliers,
    required this.supplierTransactions,
    required this.shifts,
    required this.auditEvents,
    required this.cashTransactions,
    required this.kitchenPrinters,
  });

  final ManagerDashboardSummary dashboard;
  final List<MenuCategory> categories;
  final List<MenuItem> items;
  final List<ItemSize> sizes;
  final List<ItemAddon> addons;
  final List<Recipe> recipes;
  final List<DiningTable> tables;
  final List<Order> orders;
  final PosSettings settings;
  final AppUser? currentUser;
  final List<AppUser> accounts;
  final List<Ingredient> ingredients;
  final List<IngredientStock> ingredientStocks;
  final List<InventoryTransaction> inventoryTransactions;
  final List<Supplier> suppliers;
  final List<SupplierTransaction> supplierTransactions;
  final List<Shift> shifts;
  final List<AuditEvent> auditEvents;
  final List<CashDrawerTransaction> cashTransactions;
  final List<KitchenPrinter> kitchenPrinters;
}

enum _ManagerSection {
  dashboard(Icons.dashboard, 'لوحة التحكم'),
  items(Icons.menu_book, 'الأصناف'),
  tables(Icons.table_restaurant, 'الترابيزات'),
  purchases(Icons.shopping_cart, 'المشتريات'),
  accounts(Icons.people, 'الحسابات'),
  shifts(Icons.work_history, 'الشيفتات'),
  suppliers(Icons.person_search, 'الموردين'),
  cashierHistory(Icons.history, 'سجل الكاشيرات'),
  reports(Icons.bar_chart, 'التقارير'),
  audit(Icons.security, 'سجل الأحداث'),
  settings(Icons.settings, 'الإعدادات');

  const _ManagerSection(this.icon, this.label);

  final IconData icon;
  final String label;
}

Set<Permission> _permissionsForRole(UserRole role) {
  return switch (role) {
    UserRole.admin => Permission.values.toSet(),
    UserRole.manager => {
        Permission.accessManager,
        Permission.manageItems,
        Permission.manageInventory,
        Permission.manageSuppliers,
        Permission.viewReports,
        Permission.manageSettings,
      },
    UserRole.supervisor => {
        Permission.accessPos,
        Permission.accessManager,
        Permission.manageInventory,
        Permission.manageSuppliers,
        Permission.viewReports,
      },
    UserRole.cashier => {Permission.accessPos},
  };
}

String _roleLabel(UserRole role) {
  return switch (role) {
    UserRole.cashier => 'كاشير',
    UserRole.supervisor => 'مشرف',
    UserRole.manager => 'مدير',
    UserRole.admin => 'مدير كامل',
  };
}

String _permissionLabel(Permission permission) {
  return switch (permission) {
    Permission.accessPos => 'نقطة البيع',
    Permission.accessManager => 'لوحة الإدارة',
    Permission.manageUsers => 'إدارة الحسابات',
    Permission.manageItems => 'إدارة الأصناف',
    Permission.manageInventory => 'إدارة المخزون',
    Permission.manageSuppliers => 'إدارة الموردين',
    Permission.viewReports => 'عرض التقارير',
    Permission.manageSettings => 'إدارة الإعدادات',
  };
}

String _supplierTransactionLabel(SupplierTransactionType type) {
  return switch (type) {
    SupplierTransactionType.purchaseDebtIncrease => 'توريد على الحساب',
    SupplierTransactionType.payment => 'دفعة للمورد',
    SupplierTransactionType.debtDecrease => 'تقليل مديونية',
    SupplierTransactionType.settlement => 'تصفية حساب',
    SupplierTransactionType.adjustment => 'تسوية',
  };
}

String _cashTransactionLabel(CashDrawerTransactionType type) {
  return switch (type) {
    CashDrawerTransactionType.sale => 'بيع نقدي',
    CashDrawerTransactionType.expense => 'مصروف',
    CashDrawerTransactionType.supplierPayment => 'دفع مورد',
    CashDrawerTransactionType.purchasePayment => 'دفع مشتريات',
    CashDrawerTransactionType.cashIn => 'إيداع نقدي',
    CashDrawerTransactionType.cashOut => 'سحب نقدي',
  };
}

String _inventoryTypeLabel(InventoryTransactionType type) {
  return switch (type) {
    InventoryTransactionType.purchase => 'توريد',
    InventoryTransactionType.sale => 'استخدام بيع',
    InventoryTransactionType.saleReversal => 'عكس بيع',
    InventoryTransactionType.waste => 'هالك',
    InventoryTransactionType.adjustment => 'تسوية',
  };
}

String _orderTypeLabel(OrderType type) {
  return switch (type) {
    OrderType.takeaway => 'تيك أواي',
    OrderType.dineIn => 'صالة',
    OrderType.delivery => 'دليفري',
  };
}

String _orderStatusLabel(OrderStatus status) {
  return switch (status) {
    OrderStatus.unpaid => 'غير مدفوع',
    OrderStatus.paid => 'مدفوع',
    OrderStatus.cancelled => 'ملغي',
  };
}

String _shiftStatusLabel(ShiftStatus status) {
  return switch (status) {
    ShiftStatus.open => 'مفتوح',
    ShiftStatus.closed => 'مغلق',
  };
}

String _menuItemTypeName(MenuItemType type) {
  return switch (type) {
    MenuItemType.product => 'منتج',
    MenuItemType.rawMaterial => 'مادة خام',
    MenuItemType.service => 'خدمة',
  };
}

String _productTypeName(ProductType type) {
  return switch (type) {
    ProductType.recipe => 'وصفة',
    ProductType.readyMade => 'جاهز',
    ProductType.manufactured => 'تصنيع داخلي',
    ProductType.noInventory => 'بدون مخزون',
  };
}

String _menuItemTypeLabel(MenuItem item) {
  if (item.itemType != MenuItemType.product) {
    return _menuItemTypeName(item.itemType);
  }
  return _productTypeName(item.productType);
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

bool _sameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
