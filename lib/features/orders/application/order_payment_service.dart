import '../domain/order.dart';
import '../domain/order_enums.dart';
import '../domain/order_repository.dart';

class OrderPaymentService {
  const OrderPaymentService({
    required this.orderRepository,
  });

  final OrderRepository orderRepository;

  Future<Order> markPaid({
    required String orderId,
    required PaymentMethod method,
    DateTime? paidAt,
  }) async {
    final order = await orderRepository.getById(orderId);
    if (order == null) {
      throw StateError('Order was not found.');
    }
    if (order.status == OrderStatus.cancelled) {
      throw StateError('Cancelled orders cannot be paid.');
    }
    if (order.status == OrderStatus.paid) {
      throw StateError('Order is already paid.');
    }

    final paidOrder = order.markPaid(
      method: method,
      paidAt: paidAt ?? DateTime.now(),
    );

    return orderRepository.save(paidOrder);
  }
}
