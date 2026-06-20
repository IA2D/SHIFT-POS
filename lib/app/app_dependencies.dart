import '../features/menu/data/in_memory_menu_repository.dart';
import '../features/menu/domain/menu_repository.dart';
import '../features/orders/data/in_memory_order_repository.dart';
import '../features/orders/domain/order_repository.dart';
import '../features/tables/data/in_memory_table_repository.dart';
import '../features/tables/domain/table_repository.dart';

class AppDependencies {
  AppDependencies({
    MenuRepository? menuRepository,
    TableRepository? tableRepository,
    OrderRepository? orderRepository,
  })  : menuRepository = menuRepository ?? InMemoryMenuRepository.seeded(),
        tableRepository = tableRepository ?? InMemoryTableRepository.seeded(),
        orderRepository = orderRepository ?? InMemoryOrderRepository();

  final MenuRepository menuRepository;
  final TableRepository tableRepository;
  final OrderRepository orderRepository;
}
