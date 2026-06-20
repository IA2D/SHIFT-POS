import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/data/in_memory_order_repository.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';

void main() {
  test('assigns increasing order numbers', () async {
    final repository = InMemoryOrderRepository();

    expect(await repository.nextOrderNumber(), 1);
    expect(await repository.nextOrderNumber(), 2);
  });

  test('lists unpaid dine-in orders only', () async {
    final repository = InMemoryOrderRepository();
    final now = DateTime.utc(2026, 6, 20);

    await repository.save(
      Order(
        id: 'dine',
        orderNumber: 1,
        type: OrderType.dineIn,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 0,
          discountAmount: 0,
          taxAmount: 0,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 0,
        ),
        status: OrderStatus.unpaid,
        createdAt: now,
        tableId: 't1',
        tableNameAr: 'ترابيزة 1',
      ),
    );
    await repository.save(
      Order(
        id: 'takeaway',
        orderNumber: 2,
        type: OrderType.takeaway,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 0,
          discountAmount: 0,
          taxAmount: 0,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 0,
        ),
        status: OrderStatus.paid,
        createdAt: now,
      ),
    );

    final unpaid = await repository.listUnpaidDineInOrders();

    expect(unpaid.map((order) => order.id), ['dine']);
  });
}
