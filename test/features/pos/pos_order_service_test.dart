import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/data/in_memory_order_repository.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/pos/application/cart_line.dart';
import 'package:shift_pos/features/pos/application/pos_order_service.dart';
import 'package:shift_pos/features/tables/domain/dining_table.dart';

void main() {
  final cart = [
    const CartLine(menuItemId: 'kofta', nameAr: 'كفتة', unitPrice: 100, quantity: 2),
  ];

  test('creates paid takeaway order', () async {
    final repository = InMemoryOrderRepository();
    final service = PosOrderService(orderRepository: repository);

    final order = await service.createOrder(
      cart: cart,
      type: OrderType.takeaway,
      taxRate: 14,
      serviceRate: 0,
      paymentMethod: PaymentMethod.cash,
      now: DateTime.utc(2026, 6, 20),
    );

    expect(order.orderNumber, 1);
    expect(order.status, OrderStatus.paid);
    expect(order.paymentMethod, PaymentMethod.cash);
    expect(order.totals.subtotal, 200);
    expect(order.totals.taxAmount, 28);
    expect(order.totals.total, 228);
  });

  test('creates unpaid dine-in order with table', () async {
    final repository = InMemoryOrderRepository();
    final service = PosOrderService(orderRepository: repository);

    final order = await service.createOrder(
      cart: cart,
      type: OrderType.dineIn,
      taxRate: 14,
      serviceRate: 0,
      table: const DiningTable(id: 't1', nameAr: 'ترابيزة 1', sectionAr: 'الصالة'),
      now: DateTime.utc(2026, 6, 20),
    );

    expect(order.status, OrderStatus.unpaid);
    expect(order.paymentMethod, isNull);
    expect(order.tableId, 't1');
  });

  test('blocks dine-in order without table', () async {
    final service = PosOrderService(orderRepository: InMemoryOrderRepository());

    expect(
      () => service.createOrder(
        cart: cart,
        type: OrderType.dineIn,
        taxRate: 14,
        serviceRate: 0,
      ),
      throwsStateError,
    );
  });
}
