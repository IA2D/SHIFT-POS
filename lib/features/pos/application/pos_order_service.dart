import '../../../shared/domain/money.dart';
import '../../orders/application/order_pricing_service.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_enums.dart';
import '../../orders/domain/order_pricing.dart';
import '../../orders/domain/order_repository.dart';
import '../../tables/domain/dining_table.dart';
import 'cart_line.dart';

class PosOrderService {
  const PosOrderService({
    required this.orderRepository,
    this.pricingService = const OrderPricingService(),
  });

  final OrderRepository orderRepository;
  final OrderPricingService pricingService;

  Future<Order> createOrder({
    required List<CartLine> cart,
    required OrderType type,
    required double taxRate,
    required double serviceRate,
    double deliveryFee = 0,
    DiningTable? table,
    PaymentMethod? paymentMethod,
    String? noteAr,
    DateTime? now,
  }) async {
    if (cart.isEmpty) {
      throw StateError('Cart cannot be empty.');
    }
    if (type == OrderType.dineIn && table == null) {
      throw StateError('Dine-in orders require a table.');
    }
    if (type != OrderType.dineIn && paymentMethod == null) {
      throw StateError('Paid orders require a payment method.');
    }

    final createdAt = now ?? DateTime.now();
    final lines = cart.map((line) => line.toOrderLine()).toList(growable: false);
    final totals = pricingService.calculate(
      OrderPricingInput(
        lines: lines,
        orderType: type,
        taxRate: taxRate,
        serviceRate: serviceRate,
        deliveryFee: deliveryFee,
      ),
    );
    final orderNumber = await orderRepository.nextOrderNumber();
    final isDineIn = type == OrderType.dineIn;
    final order = Order(
      id: 'order-${createdAt.microsecondsSinceEpoch}-$orderNumber',
      orderNumber: orderNumber,
      type: type,
      lines: lines,
      totals: totals,
      status: isDineIn ? OrderStatus.unpaid : OrderStatus.paid,
      createdAt: createdAt,
      tableId: table?.id,
      tableNameAr: table?.nameAr,
      noteAr: noteAr?.trim().isEmpty ?? true ? null : noteAr!.trim(),
      paidAt: isDineIn ? null : createdAt,
      paymentMethod: isDineIn ? null : paymentMethod,
    );

    return orderRepository.save(order);
  }

  double cartSubtotal(List<CartLine> cart) {
    return Money.round(
      cart.fold<double>(0, (sum, line) => sum + (line.unitPrice * line.quantity)),
    );
  }
}
