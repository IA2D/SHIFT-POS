// ignore_for_file: require_trailing_commas, prefer_is_not_empty

import 'package:flutter/material.dart';

import '../../../app/app_command_bus.dart';
import '../../../app/app_dependencies.dart';
import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/printing/platform_print_service.dart';
import '../../../shared/domain/money.dart';
import '../../../shared/theme/app_theme.dart';
import '../../menu/domain/menu_category.dart';
import '../../menu/domain/menu_item.dart';
import '../../orders/application/order_payment_service.dart';
import '../../orders/application/order_pricing_service.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../orders/domain/order_pricing.dart';
import '../../orders/domain/order_repository.dart';
import '../../printers/application/kitchen_ticket_text_builder.dart';
import '../../pos/application/cart_line.dart';
import '../../pos/application/pos_order_service.dart';
import '../../settings/domain/pos_settings.dart';
import '../../tables/domain/dining_table.dart';
import '../../cash/domain/cash_drawer_transaction.dart';
import '../../tables/presentation/floor_table_picker_dialog.dart';

double? _parseMoney(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

class PosPage extends StatefulWidget {
  const PosPage({
    required this.config,
    super.key,
  });

  final AppConfig config;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final List<CartLine> _cart = [];
  final List<_HeldOrder> _heldOrders = [];
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _splitCashController = TextEditingController();
  final TextEditingController _splitCardController = TextEditingController();
  final TextEditingController _discountValueController =
      TextEditingController();
  final TextEditingController _deliveryFeeController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();
  List<MenuCategory> _categories = [];
  List<MenuItem> _items = [];
  List<DiningTable> _tables = [];
  PosSettings? _settings;
  String? _selectedCategoryId;
  String _search = '';
  OrderType _orderType = OrderType.takeaway;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DiscountType _discountType = DiscountType.percent;
  DiningTable? _selectedTable;
  bool _loading = true;
  String? _message;
  AppDependencies? _dependencies;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim());
    });
    Future<void>.microtask(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dependencies = AppStateScope.of(context);
    if (identical(_dependencies, dependencies)) return;
    _dependencies?.commandBus.removeListener(_handleAppCommand);
    _dependencies = dependencies;
    dependencies.commandBus.addListener(_handleAppCommand);
  }

  @override
  void dispose() {
    _dependencies?.commandBus.removeListener(_handleAppCommand);
    _noteController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cashReceivedController.dispose();
    _splitCashController.dispose();
    _splitCardController.dispose();
    _discountValueController.dispose();
    _deliveryFeeController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  void _handleAppCommand() {
    switch (_dependencies?.commandBus.lastCommand) {
      case AppCommand.newOrder:
        setState(() {
          _cart.clear();
          _noteController.clear();
          _resetCheckoutFields(clearDelivery: true);
          _message = null;
        });
      case AppCommand.checkoutCash:
        _openCheckout(method: PaymentMethod.cash);
      case AppCommand.checkoutCard:
        _openCheckout(method: PaymentMethod.card);
      case AppCommand.holdOrder:
        _holdCurrentOrder();
      case AppCommand.focusSearch:
        _searchFocusNode.requestFocus();
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      case null:
        break;
    }
  }

  Future<void> _load() async {
    final dependencies = AppStateScope.of(context);
    final categories = await dependencies.menuRepository.listCategories();
    final items = await dependencies.menuRepository.listItems();
    final tables = await dependencies.tableRepository.listTables();
    final settings = await dependencies.settingsRepository.getPosSettings();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _items = items;
      _tables = tables;
      _settings = settings;
      _selectedTable = tables.isEmpty ? null : tables.first;
      _loading = false;
    });
  }

  List<MenuItem> get _visibleItems {
    final selected = _selectedCategoryId;
    final query = _search.toLowerCase();
    return _items.where((item) {
      final matchesCategory = selected == null || item.categoryId == selected;
      final matchesSearch = query.isEmpty ||
          item.nameAr.toLowerCase().contains(query) ||
          item.id.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList(growable: false);
  }

  double get _subtotal {
    return Money.round(
      _cart.fold<double>(
        0,
        (sum, line) => sum + (line.unitPrice * line.quantity),
      ),
    );
  }

  double get _previewTotal {
    return _calculateTotals().total;
  }

  OrderTotals _calculateTotals() {
    final settings = _settings;
    if (settings == null) {
      return const OrderTotals(
        subtotal: 0,
        discountAmount: 0,
        taxAmount: 0,
        serviceAmount: 0,
        deliveryFee: 0,
        total: 0,
      );
    }
    final lines =
        _cart.map((line) => line.toOrderLine()).toList(growable: false);
    return const OrderPricingService().calculate(
      OrderPricingInput(
        lines: lines,
        orderType: _orderType,
        taxRate: settings.taxRate,
        serviceRate: settings.serviceRate,
        deliveryFee: _orderType == OrderType.delivery
            ? (_parseMoney(_deliveryFeeController.text) ?? settings.deliveryFee)
            : 0,
        discountType:
            _discountValueController.text.trim().isEmpty ? null : _discountType,
        discountValue: _parseMoney(_discountValueController.text) ?? 0,
      ),
    );
  }

  void _addItem(MenuItem item) {
    final index = _cart.indexWhere((line) => line.menuItemId == item.id);
    setState(() {
      if (index == -1) {
        _cart.add(CartLine.fromMenuItem(item));
      } else {
        final line = _cart[index];
        _cart[index] = line.copyWith(quantity: line.quantity + 1);
      }
      _message = null;
    });
  }

  void _changeQuantity(CartLine line, double delta) {
    final index =
        _cart.indexWhere((current) => current.menuItemId == line.menuItemId);
    if (index == -1) return;
    setState(() {
      final nextQuantity = _cart[index].quantity + delta;
      if (nextQuantity <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = _cart[index].copyWith(quantity: nextQuantity);
      }
    });
  }

  Future<void> _submitOrder({
    PaymentMethod? method,
    _CheckoutResult? checkout,
  }) async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف صنف واحد على الأقل.');
      return;
    }
    if (_orderType == OrderType.dineIn && _selectedTable == null) {
      setState(() => _message = 'اختر ترابيزة لطلب الصالة.');
      return;
    }

    final dependencies = AppStateScope.of(context);
    final service =
        PosOrderService(orderRepository: dependencies.orderRepository);

    try {
      final currentUser = await dependencies.authRepository.currentUser();
      final shift = currentUser == null
          ? null
          : await dependencies.shiftRepository
              .getOpenShiftForCashier(currentUser.id);
      final order = await service.createOrder(
        cart: _cart,
        type: _orderType,
        taxRate: _settings?.taxRate ?? 0,
        serviceRate: _settings?.serviceRate ?? 0,
        deliveryFee: _orderType == OrderType.delivery
            ? (_parseMoney(_deliveryFeeController.text) ??
                _settings?.deliveryFee ??
                0)
            : 0,
        discountType: checkout?.discountType,
        discountValue: checkout?.discountValue ?? 0,
        table: _orderType == OrderType.dineIn ? _selectedTable : null,
        paymentMethod:
            _orderType == OrderType.dineIn ? null : (method ?? _paymentMethod),
        cashPaid: checkout?.cashPaid,
        cardPaid: checkout?.cardPaid,
        cashReceived: checkout?.cashReceived,
        changeDue: checkout?.changeDue,
        customerName: _orderType == OrderType.delivery
            ? _customerNameController.text
            : null,
        customerPhone: _orderType == OrderType.delivery
            ? _customerPhoneController.text
            : null,
        customerAddress: _orderType == OrderType.delivery
            ? _customerAddressController.text
            : null,
        cashierId: currentUser?.id,
        cashierName: currentUser?.displayName,
        shiftId: shift?.id,
        noteAr: _noteController.text,
      );
      if (order.status == OrderStatus.paid && (order.cashPaid ?? 0) > 0) {
        await dependencies.cashRepository.saveTransaction(
          CashDrawerTransaction(
            id: 'cash-sale-${order.id}',
            type: CashDrawerTransactionType.sale,
            amount: order.cashPaid!,
            shiftId: order.shiftId,
            orderId: order.id,
            noteAr: 'بيع طلب #${order.orderNumber}',
            createdBy: currentUser?.id ?? 'local',
            createdAt: order.paidAt ?? DateTime.now(),
          ),
        );
      }
      final printWarning = await _printKitchenTickets(order, dependencies);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _noteController.clear();
        _resetCheckoutFields(clearDelivery: _orderType != OrderType.delivery);
        _message = order.status == OrderStatus.unpaid
            ? 'تم فتح طلب صالة #${order.orderNumber}'
            : 'تم حفظ طلب مدفوع #${order.orderNumber}';
      });
      if (printWarning != null) {
        setState(() => _message = '$_message\n$printWarning');
      }
    } on StateError catch (error) {
      setState(() => _message = error.message);
    }
  }

  Future<String?> _printKitchenTickets(
    Order order,
    AppDependencies dependencies,
  ) async {
    final printers = await dependencies.printerRepository.listKitchenPrinters(
      activeOnly: true,
    );
    if (printers.isEmpty) return null;
    final itemById = {for (final item in _items) item.id: item};
    final failures = <String>[];
    for (final printer in printers) {
      final lines = order.lines.where((line) {
        return itemById[line.menuItemId]
                ?.kitchenPrinterIds
                .contains(printer.id) ??
            false;
      }).toList();
      if (lines.isEmpty) continue;
      final ticket = const KitchenTicketTextBuilder().build(
        order,
        printer,
        lines,
      );
      final result = await const PlatformPrintService().printText(
        ticket,
        printerName: printer.deviceName,
        copies: printer.copies,
      );
      if (!result.ok) failures.add('${printer.name}: ${result.error}');
    }
    return failures.isEmpty
        ? null
        : 'Kitchen print failed: ${failures.join('; ')}';
  }

  Future<void> _openCheckout(
      {PaymentMethod method = PaymentMethod.cash}) async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف صنف واحد على الأقل.');
      return;
    }
    setState(() {
      _paymentMethod = method;
      _message = null;
    });

    final result = await showDialog<_CheckoutResult>(
      context: context,
      builder: (context) => _CheckoutDialog(
        orderType: _orderType,
        initialMethod: method,
        totals: _calculateTotals(),
        currencySymbol: _settings?.currencySymbol ?? 'ج.م',
        discountType: _discountType,
        discountValueController: _discountValueController,
        cashReceivedController: _cashReceivedController,
        splitCashController: _splitCashController,
        splitCardController: _splitCardController,
        deliveryFeeController: _deliveryFeeController,
        customerNameController: _customerNameController,
        customerPhoneController: _customerPhoneController,
        customerAddressController: _customerAddressController,
        onDiscountTypeChanged: (value) => _discountType = value,
        recalculateTotals: () {
          setState(() {});
          return _calculateTotals();
        },
      ),
    );
    if (result == null) return;
    await _submitOrder(method: result.method, checkout: result);
  }

  void _holdCurrentOrder() {
    if (_cart.isEmpty) {
      setState(() => _message = 'لا يوجد طلب لتعليقه.');
      return;
    }
    final label = switch (_orderType) {
      OrderType.dineIn => 'صالة ${_selectedTable?.nameAr ?? ''}',
      OrderType.delivery => 'دليفري ${_customerNameController.text}',
      OrderType.takeaway => 'تيك أواي',
    };
    setState(() {
      _heldOrders.add(
        _HeldOrder(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: '$label - ${_cart.length} صنف',
          cart: List<CartLine>.from(_cart),
          orderType: _orderType,
          selectedTable: _selectedTable,
          note: _noteController.text,
          discountType: _discountType,
          discountValue: _discountValueController.text,
          deliveryFee: _deliveryFeeController.text,
          customerName: _customerNameController.text,
          customerPhone: _customerPhoneController.text,
          customerAddress: _customerAddressController.text,
        ),
      );
      _cart.clear();
      _noteController.clear();
      _resetCheckoutFields(clearDelivery: true);
      _message = 'تم تعليق الطلب.';
    });
  }

  Future<void> _openHeldOrders() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _HeldOrdersDialog(
        heldOrders: _heldOrders,
        onResume: (held) {
          setState(() {
            _cart
              ..clear()
              ..addAll(held.cart);
            _orderType = held.orderType;
            _selectedTable = held.selectedTable;
            _noteController.text = held.note;
            _discountType = held.discountType;
            _discountValueController.text = held.discountValue;
            _deliveryFeeController.text = held.deliveryFee;
            _customerNameController.text = held.customerName;
            _customerPhoneController.text = held.customerPhone;
            _customerAddressController.text = held.customerAddress;
            _heldOrders.removeWhere((order) => order.id == held.id);
            _message = 'تم استعادة الطلب المعلق.';
          });
          Navigator.of(context).pop();
        },
        onDelete: (held) {
          setState(() {
            _heldOrders.removeWhere((order) => order.id == held.id);
          });
        },
      ),
    );
  }

  void _resetCheckoutFields({required bool clearDelivery}) {
    _cashReceivedController.clear();
    _splitCashController.clear();
    _splitCardController.clear();
    _discountValueController.clear();
    _discountType = DiscountType.percent;
    if (clearDelivery) {
      _deliveryFeeController.clear();
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customerAddressController.clear();
    }
  }

  Future<void> _openUnpaidDineInDialog() async {
    final dependencies = AppStateScope.of(context);
    final currencySymbol = _settings?.currencySymbol ?? 'ج.م';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _UnpaidDineInDialog(
          orderRepository: dependencies.orderRepository,
          currencySymbol: currencySymbol,
          onPaid: (order, method) async {
            final service = OrderPaymentService(
              orderRepository: dependencies.orderRepository,
            );
            final paid = await service.markPaid(
              orderId: order.id,
              method: method,
              cashPaid: method == PaymentMethod.cash ? order.totals.total : 0,
              cardPaid: method == PaymentMethod.card ? order.totals.total : 0,
              cashReceived:
                  method == PaymentMethod.cash ? order.totals.total : null,
              changeDue: method == PaymentMethod.cash ? 0 : null,
            );
            if (method == PaymentMethod.cash) {
              final currentUser =
                  await dependencies.authRepository.currentUser();
              await dependencies.cashRepository.saveTransaction(
                CashDrawerTransaction(
                  id: 'cash-sale-${paid.id}',
                  type: CashDrawerTransactionType.sale,
                  amount: paid.totals.total,
                  shiftId: paid.shiftId,
                  orderId: paid.id,
                  noteAr: 'تحصيل طلب صالة #${paid.orderNumber}',
                  createdBy: currentUser?.id ?? 'local',
                  createdAt: paid.paidAt ?? DateTime.now(),
                ),
              );
            }
            if (!mounted) return;
            setState(() {
              _message = 'تم تحصيل طلب الصالة #${paid.orderNumber}';
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencySymbol = _settings?.currencySymbol ?? 'ج.م';
    final cartPanel = _CartPanel(
      cart: _cart,
      subtotal: _subtotal,
      total: _previewTotal,
      currencySymbol: currencySymbol,
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      selectedTable: _selectedTable,
      tables: _tables,
      noteController: _noteController,
      message: _message,
      onOpenUnpaidDineIn: _openUnpaidDineInDialog,
      onOrderTypeChanged: (value) {
        setState(() {
          _orderType = value;
          _message = null;
        });
      },
      onPaymentMethodChanged: (value) {
        setState(() => _paymentMethod = value);
      },
      onTableChanged: (value) {
        setState(() => _selectedTable = value);
      },
      onQuantityChanged: _changeQuantity,
      onSubmit: () => _submitOrder(),
      onQuickPay: (method) => _openCheckout(method: method),
      heldCount: _heldOrders.length,
      onHold: _holdCurrentOrder,
      onOpenHeldOrders: _openHeldOrders,
    );
    final menuPanel = _MenuPanel(
      categories: _categories,
      selectedCategoryId: _selectedCategoryId,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      items: _visibleItems,
      currencySymbol: currencySymbol,
      onCategoryChanged: (id) {
        setState(() => _selectedCategoryId = id);
      },
      onItemPressed: _addItem,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SizedBox(height: 520, child: cartPanel),
              const SizedBox(height: 12),
              SizedBox(height: 560, child: menuPanel),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 380, child: cartPanel),
              const SizedBox(width: 12),
              Expanded(child: menuPanel),
            ],
          ),
        );
      },
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.categories,
    required this.selectedCategoryId,
    required this.searchController,
    required this.searchFocusNode,
    required this.items,
    required this.currencySymbol,
    required this.onCategoryChanged,
    required this.onItemPressed,
  });

  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<MenuItem> items;
  final String currencySymbol;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<MenuItem> onItemPressed;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LogoMark(),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث في الأصناف',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final category = isAll ? null : categories[index - 1];
                final id = category?.id;
                final selected = selectedCategoryId == id;
                return _CategoryButton(
                  label: isAll ? 'الكل' : category!.nameAr,
                  selected: selected,
                  onPressed: () => onCategoryChanged(id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد أصناف مطابقة',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.18,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _MenuItemTile(
                        item: item,
                        currencySymbol: currencySymbol,
                        onPressed: () => onItemPressed(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.cart,
    required this.subtotal,
    required this.total,
    required this.currencySymbol,
    required this.orderType,
    required this.paymentMethod,
    required this.selectedTable,
    required this.tables,
    required this.noteController,
    required this.message,
    required this.onOpenUnpaidDineIn,
    required this.onOrderTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onTableChanged,
    required this.onQuantityChanged,
    required this.onSubmit,
    required this.onQuickPay,
    required this.heldCount,
    required this.onHold,
    required this.onOpenHeldOrders,
  });

  final List<CartLine> cart;
  final double subtotal;
  final double total;
  final String currencySymbol;
  final OrderType orderType;
  final PaymentMethod paymentMethod;
  final DiningTable? selectedTable;
  final List<DiningTable> tables;
  final TextEditingController noteController;
  final String? message;
  final VoidCallback onOpenUnpaidDineIn;
  final ValueChanged<OrderType> onOrderTypeChanged;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final ValueChanged<DiningTable?> onTableChanged;
  final void Function(CartLine line, double delta) onQuantityChanged;
  final VoidCallback onSubmit;
  final ValueChanged<PaymentMethod> onQuickPay;
  final int heldCount;
  final VoidCallback onHold;
  final VoidCallback onOpenHeldOrders;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الطلب الحالي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onOpenUnpaidDineIn,
                icon: const Icon(Icons.table_restaurant, size: 18),
                label: const Text('الصالة'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onOpenHeldOrders,
                icon: const Icon(Icons.pause_circle_outline, size: 18),
                label: Text('معلق $heldCount'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _OrderTypeToggle(
            value: orderType,
            onChanged: onOrderTypeChanged,
          ),
          if (orderType == OrderType.dineIn) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final table = await showFloorTablePickerDialog(
                  context,
                  tables: tables,
                  selected: selectedTable,
                );
                if (table != null) onTableChanged(table);
              },
              icon: const Icon(Icons.table_restaurant),
              label: Text(
                selectedTable == null
                    ? 'اختيار الترابيزة'
                    : '${selectedTable!.nameAr} - ${selectedTable!.sectionAr}',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final line = cart[index];
                      return _CartLineTile(
                        line: line,
                        currencySymbol: currencySymbol,
                        onQuantityChanged: onQuantityChanged,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: 'ملاحظة على الطلب'),
            minLines: 1,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          _TotalsBox(
            subtotal: subtotal,
            total: total,
            currencySymbol: currencySymbol,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message!.contains('أضف') || message!.contains('اختر')
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
                border: Border.all(
                  color: message!.contains('أضف') || message!.contains('اختر')
                      ? AppTheme.danger
                      : AppTheme.success,
                  width: 2,
                ),
              ),
              child: Text(
                message!,
                style: TextStyle(
                  color: message!.contains('أضف') || message!.contains('اختر')
                      ? AppTheme.danger
                      : AppTheme.success,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!cart.isEmpty) ...[
            OutlinedButton.icon(
              onPressed: onHold,
              icon: const Icon(Icons.pause, size: 18),
              label: const Text('تعليق الطلب'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
            ),
            const SizedBox(height: 8),
          ],
          _CheckoutActions(
            orderType: orderType,
            paymentMethod: paymentMethod,
            cartEmpty: cart.isEmpty,
            onPaymentMethodChanged: onPaymentMethodChanged,
            onQuickPay: onQuickPay,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppTheme.text,
        border: Border.all(color: brand, width: 3),
      ),
      alignment: Alignment.center,
      child: const Text(
        'SHIFT',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? brand : AppTheme.surface,
        foregroundColor: selected ? Colors.white : AppTheme.text,
        minimumSize: const Size(86, 38),
        side: BorderSide(
          color: selected ? brand : AppTheme.border,
          width: 2,
        ),
      ),
      child: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _MenuItemTile extends StatelessWidget {
  const _MenuItemTile({
    required this.item,
    required this.currencySymbol,
    required this.onPressed,
  });

  final MenuItem item;
  final String currencySymbol;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return Material(
      color: AppTheme.surface,
      child: InkWell(
        onTap: onPressed,
        hoverColor: const Color(0xFFE0F4F8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    item.nameAr,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: brand,
                alignment: Alignment.center,
                child: Text(
                  '${item.price.toStringAsFixed(2)} $currencySymbol',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTypeToggle extends StatelessWidget {
  const _OrderTypeToggle({
    required this.value,
    required this.onChanged,
  });

  final OrderType value;
  final ValueChanged<OrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToggleButton(
            label: 'تيك أواي',
            selected: value == OrderType.takeaway,
            onPressed: () => onChanged(OrderType.takeaway),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ToggleButton(
            label: 'صالة',
            selected: value == OrderType.dineIn,
            onPressed: () => onChanged(OrderType.dineIn),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _ToggleButton(
            label: 'دليفري',
            selected: value == OrderType.delivery,
            onPressed: () => onChanged(OrderType.delivery),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).colorScheme.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? brand : AppTheme.surface,
        foregroundColor: selected ? Colors.white : AppTheme.text,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        side: BorderSide(
          color: selected ? brand : AppTheme.border,
          width: 2,
        ),
      ),
      child: FittedBox(child: Text(label)),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.borderLight),
      ),
      alignment: Alignment.center,
      child: const Text(
        'أضف أصناف من القائمة',
        style: TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.currencySymbol,
    required this.onQuantityChanged,
  });

  final CartLine line;
  final String currencySymbol;
  final void Function(CartLine line, double delta) onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.nameAr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${line.unitPrice.toStringAsFixed(2)} $currencySymbol',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _QtyButton(
            icon: Icons.remove,
            onPressed: () => onQuantityChanged(line, -1),
          ),
          SizedBox(
            width: 34,
            child: Text(
              line.quantity.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          _QtyButton(
            icon: Icons.add,
            onPressed: () => onQuantityChanged(line, 1),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          side: const BorderSide(color: AppTheme.border, width: 1.5),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _TotalsBox extends StatelessWidget {
  const _TotalsBox({
    required this.subtotal,
    required this.total,
    required this.currencySymbol,
  });

  final double subtotal;
  final double total;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: 'المجموع الفرعي',
            value: subtotal,
            currencySymbol: currencySymbol,
          ),
          const Divider(color: AppTheme.border, thickness: 2),
          _TotalRow(
            label: 'الإجمالي',
            value: total,
            currencySymbol: currencySymbol,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _CheckoutActions extends StatelessWidget {
  const _CheckoutActions({
    required this.orderType,
    required this.paymentMethod,
    required this.cartEmpty,
    required this.onPaymentMethodChanged,
    required this.onQuickPay,
    required this.onSubmit,
  });

  final OrderType orderType;
  final PaymentMethod paymentMethod;
  final bool cartEmpty;
  final ValueChanged<PaymentMethod> onPaymentMethodChanged;
  final ValueChanged<PaymentMethod> onQuickPay;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    if (orderType == OrderType.takeaway) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed:
                  cartEmpty ? null : () => onQuickPay(PaymentMethod.cash),
              child: const Text('نقدي'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              onPressed:
                  cartEmpty ? null : () => onQuickPay(PaymentMethod.card),
              child: const Text('بطاقة'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              onPressed:
                  cartEmpty ? null : () => onQuickPay(PaymentMethod.split),
              child: const Text('تقسيم'),
            ),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: cartEmpty ? null : onSubmit,
      child: Text(
        orderType == OrderType.dineIn ? 'إنشاء طلب صالة' : 'إنشاء طلب دليفري',
      ),
    );
  }
}

class _UnpaidDineInDialog extends StatefulWidget {
  const _UnpaidDineInDialog({
    required this.orderRepository,
    required this.currencySymbol,
    required this.onPaid,
  });

  final OrderRepository orderRepository;
  final String currencySymbol;
  final Future<void> Function(Order order, PaymentMethod method) onPaid;

  @override
  State<_UnpaidDineInDialog> createState() => _UnpaidDineInDialogState();
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.orderType,
    required this.initialMethod,
    required this.totals,
    required this.currencySymbol,
    required this.discountType,
    required this.discountValueController,
    required this.cashReceivedController,
    required this.splitCashController,
    required this.splitCardController,
    required this.deliveryFeeController,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.customerAddressController,
    required this.onDiscountTypeChanged,
    required this.recalculateTotals,
  });

  final OrderType orderType;
  final PaymentMethod initialMethod;
  final OrderTotals totals;
  final String currencySymbol;
  final DiscountType discountType;
  final TextEditingController discountValueController;
  final TextEditingController cashReceivedController;
  final TextEditingController splitCashController;
  final TextEditingController splitCardController;
  final TextEditingController deliveryFeeController;
  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController customerAddressController;
  final ValueChanged<DiscountType> onDiscountTypeChanged;
  final OrderTotals Function() recalculateTotals;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  late PaymentMethod _method = widget.initialMethod;
  late DiscountType _discountType = widget.discountType;
  late OrderTotals _totals = widget.totals;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      widget.discountValueController,
      widget.cashReceivedController,
      widget.splitCashController,
      widget.splitCardController,
      widget.deliveryFeeController,
    ]) {
      controller.addListener(_recalculate);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      widget.discountValueController,
      widget.cashReceivedController,
      widget.splitCashController,
      widget.splitCardController,
      widget.deliveryFeeController,
    ]) {
      controller.removeListener(_recalculate);
    }
    super.dispose();
  }

  void _recalculate() {
    setState(() => _totals = widget.recalculateTotals());
  }

  void _confirm() {
    final total = _totals.total;
    final cashReceived = _parseMoney(widget.cashReceivedController.text);
    final splitCash = _parseMoney(widget.splitCashController.text) ?? 0;
    final splitCard = _parseMoney(widget.splitCardController.text) ?? 0;
    if (_method == PaymentMethod.cash &&
        cashReceived != null &&
        cashReceived < total) {
      return;
    }
    if (_method == PaymentMethod.split &&
        splitCash + splitCard < total - 0.01) {
      return;
    }
    Navigator.of(context).pop(
      _CheckoutResult(
        method: _method,
        discountType: widget.discountValueController.text.trim().isEmpty
            ? null
            : _discountType,
        discountValue: _parseMoney(widget.discountValueController.text) ?? 0,
        cashPaid: _method == PaymentMethod.split ? splitCash : null,
        cardPaid: _method == PaymentMethod.split ? splitCard : null,
        cashReceived: _method == PaymentMethod.cash ? cashReceived : null,
        changeDue: _method == PaymentMethod.cash && cashReceived != null
            ? Money.round((cashReceived - total).clamp(0, double.infinity))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cashReceived = _parseMoney(widget.cashReceivedController.text);
    final cashInsufficient = _method == PaymentMethod.cash &&
        cashReceived != null &&
        cashReceived < _totals.total;
    final splitCash = _parseMoney(widget.splitCashController.text) ?? 0;
    final splitCard = _parseMoney(widget.splitCardController.text) ?? 0;
    final splitInsufficient = _method == PaymentMethod.split &&
        splitCash + splitCard < _totals.total - 0.01;
    final changeDue = _method == PaymentMethod.cash && cashReceived != null
        ? Money.round((cashReceived - _totals.total).clamp(0, double.infinity))
        : 0.0;

    return AlertDialog(
      title: const Text('إتمام الطلب'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(value: PaymentMethod.cash, label: Text('نقدي')),
                  ButtonSegment(
                      value: PaymentMethod.card, label: Text('بطاقة')),
                  ButtonSegment(
                      value: PaymentMethod.split, label: Text('تقسيم')),
                ],
                selected: {_method},
                onSelectionChanged: (value) {
                  setState(() => _method = value.first);
                },
              ),
              const SizedBox(height: 12),
              if (_method == PaymentMethod.cash) ...[
                TextField(
                  controller: widget.cashReceivedController,
                  decoration: const InputDecoration(
                      labelText: 'المبلغ المستلم من العميل'),
                  keyboardType: TextInputType.number,
                ),
                if (cashInsufficient)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'المبلغ المستلم أقل من الإجمالي',
                      style: TextStyle(
                          color: AppTheme.danger, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (cashReceived != null && !cashInsufficient)
                  _ChangeBox(
                      value: changeDue, currencySymbol: widget.currencySymbol),
              ],
              if (_method == PaymentMethod.split)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.splitCashController,
                        decoration: const InputDecoration(labelText: 'نقدي'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: widget.splitCardController,
                        decoration: const InputDecoration(labelText: 'بطاقة'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              if (splitInsufficient)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'مجموع التقسيم أقل من الإجمالي',
                    style: TextStyle(
                        color: AppTheme.danger, fontWeight: FontWeight.w800),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<DiscountType>(
                      initialValue: _discountType,
                      decoration: const InputDecoration(labelText: 'نوع الخصم'),
                      items: const [
                        DropdownMenuItem(
                            value: DiscountType.percent, child: Text('نسبة %')),
                        DropdownMenuItem(
                            value: DiscountType.amount,
                            child: Text('مبلغ ثابت')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _discountType = value);
                        widget.onDiscountTypeChanged(value);
                        _recalculate();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.discountValueController,
                      decoration:
                          const InputDecoration(labelText: 'خصم اختياري'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              if (widget.orderType == OrderType.delivery) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: widget.customerNameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.customerPhoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.customerAddressController,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: widget.deliveryFeeController,
                  decoration: const InputDecoration(labelText: 'رسوم التوصيل'),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 12),
              _TotalsBox(
                subtotal: _totals.subtotal,
                total: _totals.total,
                currencySymbol: widget.currencySymbol,
              ),
              if (_totals.discountAmount > 0)
                Text(
                  'خصم: ${_totals.discountAmount.toStringAsFixed(2)} ${widget.currencySymbol}',
                  style: const TextStyle(
                      color: AppTheme.danger, fontWeight: FontWeight.w800),
                ),
              if (_totals.deliveryFee > 0)
                Text(
                  'توصيل: ${_totals.deliveryFee.toStringAsFixed(2)} ${widget.currencySymbol}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: cashInsufficient || splitInsufficient ? null : _confirm,
          child: const Text('تأكيد الطلب'),
        ),
      ],
    );
  }
}

class _HeldOrdersDialog extends StatelessWidget {
  const _HeldOrdersDialog({
    required this.heldOrders,
    required this.onResume,
    required this.onDelete,
  });

  final List<_HeldOrder> heldOrders;
  final ValueChanged<_HeldOrder> onResume;
  final ValueChanged<_HeldOrder> onDelete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('الطلبات المعلقة (${heldOrders.length})'),
      content: SizedBox(
        width: 420,
        child: heldOrders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد طلبات معلقة.'),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: heldOrders
                    .map(
                      (held) => ListTile(
                        title: Text(held.label),
                        subtitle: Text('${held.cart.length} صنف'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            FilledButton(
                              onPressed: () => onResume(held),
                              child: const Text('استعادة'),
                            ),
                            OutlinedButton(
                              onPressed: () => onDelete(held),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _ChangeBox extends StatelessWidget {
  const _ChangeBox({
    required this.value,
    required this.currencySymbol,
  });

  final double value;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      color: AppTheme.success,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'الباقي للعميل',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} $currencySymbol',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutResult {
  const _CheckoutResult({
    required this.method,
    required this.discountType,
    required this.discountValue,
    this.cashPaid,
    this.cardPaid,
    this.cashReceived,
    this.changeDue,
  });

  final PaymentMethod method;
  final DiscountType? discountType;
  final double discountValue;
  final double? cashPaid;
  final double? cardPaid;
  final double? cashReceived;
  final double? changeDue;
}

class _HeldOrder {
  const _HeldOrder({
    required this.id,
    required this.label,
    required this.cart,
    required this.orderType,
    required this.selectedTable,
    required this.note,
    required this.discountType,
    required this.discountValue,
    required this.deliveryFee,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
  });

  final String id;
  final String label;
  final List<CartLine> cart;
  final OrderType orderType;
  final DiningTable? selectedTable;
  final String note;
  final DiscountType discountType;
  final String discountValue;
  final String deliveryFee;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
}

class _UnpaidDineInDialogState extends State<_UnpaidDineInDialog> {
  late Future<List<Order>> _ordersFuture;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _ordersFuture = widget.orderRepository.listUnpaidDineInOrders();
  }

  Future<void> _markPaid(Order order, PaymentMethod method) async {
    setState(() => _paying = true);
    try {
      await widget.onPaid(order, method);
      if (!mounted) return;
      setState(_reload);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('طلبات الصالة المفتوحة'),
      content: SizedBox(
        width: 620,
        child: FutureBuilder<List<Order>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            final orders = snapshot.data;
            if (orders == null) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (orders.isEmpty) {
              return const SizedBox(
                height: 120,
                child: Center(child: Text('لا توجد طلبات صالة مفتوحة.')),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return ListTile(
                    title: Text(
                      '#${order.orderNumber} - ${order.tableNameAr ?? 'صالة'}',
                    ),
                    subtitle: Text(
                      '${order.lines.length} صنف - ${order.totals.total.toStringAsFixed(2)} ${widget.currencySymbol}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _paying
                              ? null
                              : () => _markPaid(order, PaymentMethod.card),
                          child: const Text('بطاقة'),
                        ),
                        FilledButton(
                          onPressed: _paying
                              ? null
                              : () => _markPaid(order, PaymentMethod.cash),
                          child: const Text('نقدي'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.currencySymbol,
    this.strong = false,
  });

  final String label;
  final double value;
  final String currencySymbol;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
      fontSize: strong ? 18 : 13,
      color: AppTheme.text,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('${value.toStringAsFixed(2)} $currencySymbol', style: style),
        ],
      ),
    );
  }
}
