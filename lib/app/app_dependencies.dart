import '../features/auth/data/in_memory_auth_repository.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/menu/data/in_memory_menu_repository.dart';
import '../features/menu/domain/menu_repository.dart';
import '../features/orders/data/in_memory_order_repository.dart';
import '../features/orders/domain/order_repository.dart';
import '../features/settings/data/in_memory_settings_repository.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/tables/data/in_memory_table_repository.dart';
import '../features/tables/domain/table_repository.dart';

class AppDependencies {
  AppDependencies({
    MenuRepository? menuRepository,
    TableRepository? tableRepository,
    OrderRepository? orderRepository,
    AuthRepository? authRepository,
    SettingsRepository? settingsRepository,
  })  : menuRepository = menuRepository ?? InMemoryMenuRepository.seeded(),
        tableRepository = tableRepository ?? InMemoryTableRepository.seeded(),
        orderRepository = orderRepository ?? InMemoryOrderRepository(),
        authRepository = authRepository ?? InMemoryAuthRepository(),
        settingsRepository = settingsRepository ?? InMemorySettingsRepository();

  final MenuRepository menuRepository;
  final TableRepository tableRepository;
  final OrderRepository orderRepository;
  final AuthRepository authRepository;
  final SettingsRepository settingsRepository;
}
