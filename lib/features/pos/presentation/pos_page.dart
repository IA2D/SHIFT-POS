import 'package:flutter/material.dart';

import '../../../app/app_state_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/domain/money.dart';
import '../../menu/domain/menu_category.dart';
import '../../menu/domain/menu_item.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../pos/application/cart_line.dart';
import '../../pos/application/pos_order_service.dart';
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
  static const _taxRate = 14.0;
  static const _serviceRate = 0.0;
  static const _deliveryFee = 25.0;

  final List<CartLine> _cart = [];
  final TextEditingController _noteController = TextEditingController();
  List<MenuCategory> _categories = [];
  List<MenuItem> _items = [];
  List<DiningTable> _tables = [];
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
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _items = items;
      _tables = tables;
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
    final delivery = _orderType == OrderType.delivery ? _deliveryFee : 0.0;
    final taxableBase = _subtotal;
    final tax = Money.round(taxableBase * (_taxRate / 100));
    final service = Money.round(taxableBase * (_serviceRate / 100));
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
        taxRate: _taxRate,
        serviceRate: _serviceRate,
        deliveryFee: _deliveryFee,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cartPanel = _CartPanel(
      cart: _cart,
      subtotal: _subtotal,
      total: _previewTotal,
      orderType: _orderType,
      paymentMethod: _paymentMethod,
      selectedTable: _selectedTable,
      tables: _tables,
      noteController: _noteController,
      message: _message,
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
              ? Column(
                  children: [
                    SizedBox(height: 420, child: cartPanel),
                    const SizedBox(height: 16),
                    Expanded(child: menuPanel),
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
    required this.onCategoryChanged,
    required this.onItemPressed,
  });

  final List<MenuCategory> categories;
  final String? selectedCategoryId;
  final List<MenuItem> items;
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
                    Text('${item.price.toStringAsFixed(2)} ج.م'),
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
    required this.orderType,
    required this.paymentMethod,
    required this.selectedTable,
    required this.tables,
    required this.noteController,
    required this.message,
    required this.onOrderTypeChanged,
    required this.onPaymentMethodChanged,
    required this.onTableChanged,
    required this.onQuantityChanged,
    required this.onSubmit,
  });

  final List<CartLine> cart;
  final double subtotal;
  final double total;
  final OrderType orderType;
  final PaymentMethod paymentMethod;
  final DiningTable? selectedTable;
  final List<DiningTable> tables;
  final TextEditingController noteController;
  final String? message;
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
                          subtitle: Text('${line.unitPrice.toStringAsFixed(2)} ج.م'),
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
            _TotalRow(label: 'الإجمالي قبل الضريبة', value: subtotal),
            _TotalRow(label: 'الإجمالي المتوقع', value: total, strong: true),
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

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final double value;
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
          Text('${value.toStringAsFixed(2)} ج.م', style: style),
        ],
      ),
    );
  }
}
