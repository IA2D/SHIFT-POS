import 'menu_category.dart';
import 'menu_item.dart';

abstract interface class MenuRepository {
  Future<List<MenuCategory>> listCategories();

  Future<List<MenuItem>> listItems();
}
