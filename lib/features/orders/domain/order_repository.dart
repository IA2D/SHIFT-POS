import 'order.dart';

abstract interface class OrderRepository {
  Future<Order> save(Order order);

  Future<List<Order>> listOrders();

  Future<List<Order>> listUnpaidDineInOrders();

  Future<int> nextOrderNumber();
}
