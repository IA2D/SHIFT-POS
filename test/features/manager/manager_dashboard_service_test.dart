import 'package:flutter_test/flutter_test.dart';
import 'package:shift_pos/features/manager/application/manager_dashboard_service.dart';
import 'package:shift_pos/features/orders/data/in_memory_order_repository.dart';
import 'package:shift_pos/features/orders/domain/order.dart';
import 'package:shift_pos/features/orders/domain/order_enums.dart';
import 'package:shift_pos/features/orders/domain/order_pricing.dart';

void main() {
  test('summarizes paid and unpaid orders', () async {
    final repository = InMemoryOrderRepository();
    final service = ManagerDashboardService(orderRepository: repository);
    final now = DateTime.utc(2026, 6, 20);

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
    await repository.save(
      Order(
        id: 'unpaid',
        orderNumber: 2,
        type: OrderType.dineIn,
        lines: const [],
        totals: const OrderTotals(
          subtotal: 50,
          discountAmount: 0,
          taxAmount: 7,
          serviceAmount: 0,
          deliveryFee: 0,
          total: 57,
        ),
        status: OrderStatus.unpaid,
        createdAt: now.add(const Duration(minutes: 1)),
        tableId: 't1',
        tableNameAr: 'ترابيزة 1',
      ),
    );

    final summary = await service.loadSummary();

    expect(summary.orderCount, 2);
    expect(summary.paidOrderCount, 1);
    expect(summary.unpaidDineInCount, 1);
    expect(summary.salesTotal, 114);
    expect(summary.recentOrders.first.id, 'unpaid');
  });
}
