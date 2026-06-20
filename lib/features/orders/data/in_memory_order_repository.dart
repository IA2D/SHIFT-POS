import '../domain/order.dart';
import '../domain/order_repository.dart';

class InMemoryOrderRepository implements OrderRepository {
  final List<Order> _orders = [];
  int _nextOrderNumber = 1;

  @override
  Future<Order> save(Order order) async {
    final index = _orders.indexWhere((current) => current.id == order.id);
    if (index == -1) {
      _orders.add(order);
    } else {
      _orders[index] = order;
    }
    return order;
  }

  @override
  Future<List<Order>> listOrders() async {
    final orders = [..._orders];
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  @override
  Future<List<Order>> listUnpaidDineInOrders() async {
    final orders = await listOrders();
    return orders.where((order) => order.isUnpaidDineIn).toList(growable: false);
  }

  @override
  Future<int> nextOrderNumber() async {
    return _nextOrderNumber++;
  }
}
