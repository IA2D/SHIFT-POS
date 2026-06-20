import 'order.dart';

abstract interface class OrderRepository {
  Future<Order> save(Order order);

  Future<Order?> getById(String id);

  Future<List<Order>> listOrders();

  Future<List<Order>> listUnpaidDineInOrders();

  Future<int> nextOrderNumber();
}
