import '../domain/menu_category.dart';
import '../domain/menu_item.dart';
import '../domain/menu_repository.dart';

class InMemoryMenuRepository implements MenuRepository {
  InMemoryMenuRepository({
    required List<MenuCategory> categories,
    required List<MenuItem> items,
  })  : _categories = List.unmodifiable(categories),
        _items = List.unmodifiable(items);

  factory InMemoryMenuRepository.seeded() {
    return InMemoryMenuRepository(
      categories: const [
        MenuCategory(id: 'grills', nameAr: 'مشويات', sortOrder: 1),
        MenuCategory(id: 'drinks', nameAr: 'مشروبات', sortOrder: 2),
        MenuCategory(id: 'extras', nameAr: 'إضافات', sortOrder: 3),
      ],
      items: const [
        MenuItem(id: 'grilled-chicken', categoryId: 'grills', nameAr: 'فراخ مشوية', price: 200),
        MenuItem(id: 'kofta', categoryId: 'grills', nameAr: 'كفتة', price: 180),
        MenuItem(id: 'rice', categoryId: 'extras', nameAr: 'أرز', price: 35),
        MenuItem(id: 'salad', categoryId: 'extras', nameAr: 'سلطة', price: 25),
        MenuItem(id: 'cola', categoryId: 'drinks', nameAr: 'كولا', price: 25),
      ],
    );
  }

  final List<MenuCategory> _categories;
  final List<MenuItem> _items;

  @override
  Future<List<MenuCategory>> listCategories() async {
    final categories = [..._categories];
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  @override
  Future<List<MenuItem>> listItems() async {
    return _items.where((item) => item.active).toList(growable: false);
  }
}
