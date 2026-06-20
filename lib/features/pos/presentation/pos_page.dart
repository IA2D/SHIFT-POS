import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/domain/money.dart';
import '../../menu/domain/menu_category.dart';
import '../../menu/domain/menu_item.dart';
import '../../orders/application/order_payment_service.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../orders/domain/order_repository.dart';
import '../../pos/application/cart_line.dart';
import '../../pos/application/pos_order_service.dart';
import '../../settings/domain/pos_settings.dart';
import '../../tables/domain/dining_table.dart';

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
  final TextEditingController _noteController = TextEditingController();
  List<MenuCategory> _categories = [];
  List<MenuItem> _items = [];
  List<DiningTable> _tables = [];
  PosSettings? _settings;
  String? _selectedCategoryId;
  OrderType _orderType = OrderType.takeaway;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  DiningTable? _selectedTable;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
      _selectedCategoryId = categories.isEmpty ? null : categories.first.id;
      _selectedTable = tables.isEmpty ? null : tables.first;
      _loading = false;
    });
  }

  List<MenuItem> get _visibleItems {
    final selected = _selectedCategoryId;
    if (selected == null) return _items;
    return _items.where((item) => item.categoryId == selected).toList(growable: false);
  }

  double get _subtotal {
    return Money.round(
      _cart.fold<double>(0, (sum, line) => sum + (line.unitPrice * line.quantity)),
    );
  }

  double get _previewTotal {
    final settings = _settings;
    if (settings == null) return 0;
    final delivery = _orderType == OrderType.delivery ? settings.deliveryFee : 0.0;
    final taxableBase = _subtotal;
    final tax = Money.round(taxableBase * (settings.taxRate / 100));
    final service = Money.round(taxableBase * (settings.serviceRate / 100));
    return Money.round(taxableBase + tax + service + delivery);
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
    final index = _cart.indexWhere((current) => current.menuItemId == line.menuItemId);
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

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) {
      setState(() => _message = 'أضف صنف واحد على الأقل.');
      return;
    }
    if (_orderType == OrderType.dineIn && _selectedTable == null) {
      setState(() => _message = 'اختر ترابيزة لطلب الصالة.');
      return;
    }

    final dependencies = AppStateScope.of(context);
    final service = PosOrderService(orderRepository: dependencies.orderRepository);

    try {
      final order = await service.createOrder(
        cart: _cart,
        type: _orderType,
        taxRate: _settings?.taxRate ?? 0,
        serviceRate: _settings?.serviceRate ?? 0,
        deliveryFee: _settings?.deliveryFee ?? 0,
        table: _orderType == OrderType.dineIn ? _selectedTable : null,
        paymentMethod: _orderType == OrderType.dineIn ? null : _paymentMethod,
        noteAr: _noteController.text,
      );
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _noteController.clear();
        _message = order.status == OrderStatus.unpaid
            ? 'تم فتح طلب صالة #${order.orderNumber}'
            : 'تم حفظ طلب مدفوع #${order.orderNumber}';
      });
    } on StateError catch (error) {
      setState(() => _message = error.message);
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
            );
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

    final cartPanel = _CartPanel(
      cart: _cart,
      subtotal: _subtotal,
      total: _previewTotal,
      currencySymbol: _settings?.currencySymbol ?? 'ج.م',
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      selectedTable: _selectedTable,
      tables: _tables,
      noteController: _noteController,
      message: _message,
      onOpenUnpaidDineIn: _openUnpaidDineInDialog,
      onOrderTypeChanged: (value) {
        setState(() => _orderType = value);
      },
      onPaymentMethodChanged: (value) {
        setState(() => _paymentMethod = value);
      },
      onTableChanged: (value) {
        setState(() => _selectedTable = value);
      },
      onQuantityChanged: _changeQuantity,
      onSubmit: _submitOrder,
    );
    final menuPanel = _MenuPanel(
      categories: _categories,
      selectedCategoryId: _selectedCategoryId,
      items: _visibleItems,
      currencySymbol: _settings?.currencySymbol ?? 'ج.م',
      onCategoryChanged: (id) {
        setState(() => _selectedCategoryId = id);
      },
      onItemPressed: _addItem,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: compact
              ? ListView(
                  children: [
                    SizedBox(height: 450, child: cartPanel),
                    const SizedBox(height: 16),
                    SizedBox(height: 420, child: menuPanel),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 380, child: cartPanel),
                    const SizedBox(width: 16),
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
    required this.items,
    required this.currencySymbol,
    required this.onCategoryChanged,
    required this.onItemPressed,
  });

  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final List<MenuItem> items;
  final String currencySymbol;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<MenuItem> onItemPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                selected: category.id == selectedCategoryId,
                label: Text(category.nameAr),
                onSelected: (_) => onCategoryChanged(category.id),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return FilledButton.tonal(
                onPressed: () => onItemPressed(item),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.nameAr, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('${item.price.toStringAsFixed(2)} $currencySymbol'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الطلب', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenUnpaidDineIn,
              icon: const Icon(Icons.table_restaurant),
              label: const Text('طلبات الصالة المفتوحة'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<OrderType>(
              segments: const [
                ButtonSegment(value: OrderType.takeaway, label: Text('تيك أواي')),
                ButtonSegment(value: OrderType.dineIn, label: Text('صالة')),
                ButtonSegment(value: OrderType.delivery, label: Text('دليفري')),
              ],
              selected: {orderType},
              onSelectionChanged: (selection) => onOrderTypeChanged(selection.first),
            ),
            if (orderType == OrderType.dineIn) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<DiningTable>(
                initialValue: selectedTable,
                decoration: const InputDecoration(labelText: 'الترابيزة'),
                items: tables
                    .map(
                      (table) => DropdownMenuItem(
                        value: table,
                        child: Text('${table.nameAr} - ${table.sectionAr}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onTableChanged,
              ),
            ],
            if (orderType != OrderType.dineIn) ...[
              const SizedBox(height: 12),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(value: PaymentMethod.cash, label: Text('نقدي')),
                  ButtonSegment(value: PaymentMethod.card, label: Text('بطاقة')),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (selection) => onPaymentMethodChanged(selection.first),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: cart.isEmpty
                  ? const Center(child: Text('أضف أصناف من القائمة'))
                  : ListView.separated(
                      itemCount: cart.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final line = cart[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(line.nameAr),
                          subtitle: Text('${line.unitPrice.toStringAsFixed(2)} $currencySymbol'),
                          trailing: Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () => onQuantityChanged(line, -1),
                                icon: const Icon(Icons.remove),
                              ),
                              Text(line.quantity.toStringAsFixed(0)),
                              IconButton(
                                onPressed: () => onQuantityChanged(line, 1),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'ملاحظة على الطلب'),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _TotalRow(
              label: 'الإجمالي قبل الضريبة',
              value: subtotal,
              currencySymbol: currencySymbol,
            ),
            _TotalRow(
              label: 'الإجمالي المتوقع',
              value: total,
              currencySymbol: currencySymbol,
              strong: true,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.check),
              label: Text(orderType == OrderType.dineIn ? 'فتح طلب صالة' : 'حفظ الطلب'),
            ),
          ],
        ),
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
                    title: Text('#${order.orderNumber} - ${order.tableNameAr ?? 'صالة'}'),
                    subtitle: Text(
                      '${order.lines.length} صنف - ${order.totals.total.toStringAsFixed(2)} ${widget.currencySymbol}',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _paying ? null : () => _markPaid(order, PaymentMethod.card),
                          child: const Text('بطاقة'),
                        ),
                        FilledButton(
                          onPressed: _paying ? null : () => _markPaid(order, PaymentMethod.cash),
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
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

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
