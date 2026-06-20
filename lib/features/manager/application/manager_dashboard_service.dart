import '../../../shared/domain/money.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_repository.dart';

class ManagerDashboardService {
  const ManagerDashboardService({
    required this.orderRepository,
  });

  final OrderRepository orderRepository;

  Future<ManagerDashboardSummary> loadSummary() async {
    final orders = await orderRepository.listOrders();
    final paidOrders = orders.where((order) => order.status == OrderStatus.paid);
    final unpaidDineIn = orders.where((order) => order.isUnpaidDineIn).length;
    final salesTotal = paidOrders.fold<double>(
      0,
      (sum, order) => sum + order.totals.total,
    );

    return ManagerDashboardSummary(
      orderCount: orders.length,
      paidOrderCount: paidOrders.length,
      unpaidDineInCount: unpaidDineIn,
      salesTotal: Money.round(salesTotal),
      recentOrders: orders.take(8).toList(growable: false),
    );
  }
}

class ManagerDashboardSummary {
  const ManagerDashboardSummary({
    required this.orderCount,
    required this.paidOrderCount,
    required this.unpaidDineInCount,
    required this.salesTotal,
    required this.recentOrders,
  });

  final int orderCount;
  final int paidOrderCount;
  final int unpaidDineInCount;
  final double salesTotal;
  final List<Order> recentOrders;
}
