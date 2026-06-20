import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/orders/application/order_payment_service.dart';
import 'package:shift_pos/features/orders/data/in_memory_order_repository.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';

void main() {
  test('marks unpaid dine-in order as paid', () async {
    final repository = InMemoryOrderRepository();
    final service = OrderPaymentService(orderRepository: repository);
    final now = DateTime.utc(2026, 6, 20);

    await repository.save(
      Order(
        id: 'dine',
        orderNumber: 1,
        type: OrderType.dineIn,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 100,
          discountAmount: 0,
          taxAmount: 14,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 114,
        ),
        status: OrderStatus.unpaid,
        createdAt: now,
        tableId: 't1',
        tableNameAr: 'ترابيزة 1',
      ),
    );

    final paid = await service.markPaid(
      orderId: 'dine',
      method: PaymentMethod.cash,
      paidAt: now.add(const Duration(minutes: 5)),
    );

    expect(paid.status, OrderStatus.paid);
    expect(paid.paymentMethod, PaymentMethod.cash);
    expect(paid.paidAt, now.add(const Duration(minutes: 5)));
    expect(await repository.listUnpaidDineInOrders(), isEmpty);
  });

  test('rejects missing and already paid orders', () async {
    final repository = InMemoryOrderRepository();
    final service = OrderPaymentService(orderRepository: repository);
    final now = DateTime.utc(2026, 6, 20);

    expect(
      () => service.markPaid(orderId: 'missing', method: PaymentMethod.cash),
      throwsStateError,
    );

    await repository.save(
      Order(
        id: 'paid',
        orderNumber: 1,
        type: OrderType.takeaway,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 100,
          discountAmount: 0,
          taxAmount: 14,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 114,
        ),
        status: OrderStatus.paid,
        createdAt: now,
      ),
    );

    expect(
      () => service.markPaid(orderId: 'paid', method: PaymentMethod.cash),
      throwsStateError,
    );
  });
}
